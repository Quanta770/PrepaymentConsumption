CLASS zcl_openio_prepay_delv DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES: if_amdp_marker_hdb.
    CLASS-METHODS: execute FOR TABLE FUNCTION ZI_OPENIO_ROWS_MATCHING.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_OPENIO_PREPAY_DELV IMPLEMENTATION.


    METHOD execute BY DATABASE FUNCTION FOR HDB
         LANGUAGE SQLSCRIPT
         OPTIONS READ-ONLY
         USING ZI_OPENIO_STAGING_ROWS.

    -- -------------------------------------------------------------------------
    -- Step 1: Place every OPEN prepay item onto a global money axis.
    --         Items are ordered FIFO by document date, then SO number, then item.
    --         Each item occupies the band [cum_prepay_lo, cum_prepay_hi].
    -- -------------------------------------------------------------------------
    lv_prepay_ranked =
      select
        session_context('CLIENT')       as rclnt,
        SessionId,
        PrepaymentReqNumPrepayment,
        Prepaymentso,
        Prepaymentsoitem,
        Prepaymentsalesorg,
        Prepaymentsoldto,
        Prepaymentscenariopy,
        Prepaymentcurrency,
        Prepaymentnetamount,
        Prepaymentremainingamount,
        Prepaydocdate,
*         upper edge of this item's band (inclusive)
        sum( Prepaymentremainingamount ) over (
          partition by SessionId, Prepaymentsoldto, Prepaymentcurrency
          order by Prepaydocdate      asc,
                   Prepaymentso                asc,
                   cast( Prepaymentsoitem as integer ) asc
          rows between unbounded preceding and current row
        ) as cum_prepay_hi,
*        -- lower edge of this item's band (exclusive); 0 for the very first item
        coalesce(
          sum( Prepaymentremainingamount ) over (
             partition by SessionId, Prepaymentsoldto, Prepaymentcurrency
            order by Prepaydocdate      asc,
                     Prepaymentso                asc,
                     cast( Prepaymentsoitem as integer ) asc
            rows between unbounded preceding and 1 preceding
          ), 0
        ) as cum_prepay_lo
      from (
        -- Deduplicate: one row per unique prepay item
        select distinct
          SessionId, PrepaymentReqNumPrepayment, Prepaymentso,
          Prepaymentsoitem, Prepaymentsalesorg, Prepaymentsoldto,
          Prepaymentscenariopy, Prepaymentcurrency, Prepaymentnetamount,
          Prepaymentremainingamount, Prepaydocdate
        from ZI_OPENIO_STAGING_ROWS
        where Prepaymentremainingamount > 0
      );

*    -- -------------------------------------------------------------------------
*    -- Step 2: Place every OPEN delivery item onto the same global money axis.
*    --         Same FIFO ordering logic earliest document date first.
*    --         Each item occupies the band [cum_delv_lo, cum_delv_hi].
*    -- -------------------------------------------------------------------------
    lv_delv_ranked =
      select
        SessionId,
        Delvsosalesdocument,
        Delvsosalesdocumentitem,
        Delvsosalesorg,
        Delvsosoldto,
        Delvsoscenario,
        Delvsocurrency,
        Delvsonetamount,
        Delvremainingamount,
        Delvdocdate,
        -- upper edge
        sum( Delvremainingamount ) over (
          partition by SessionId, Delvsosoldto, Delvsocurrency
          order by Delvdocdate               asc,
                   Delvsosalesdocument             asc,
                   cast( Delvsosalesdocumentitem as integer ) asc
          rows between unbounded preceding and current row
        ) as cum_delv_hi,
        -- lower edge
        coalesce(
          sum( Delvremainingamount ) over (
            partition by SessionId, Delvsosoldto, Delvsocurrency
            order by Delvdocdate               asc,
                     Delvsosalesdocument             asc,
                     cast( Delvsosalesdocumentitem as integer ) asc
            rows between unbounded preceding and 1 preceding
          ), 0
        ) as cum_delv_lo
      from (
        -- Deduplicate: one row per unique delivery item
        select distinct
          SessionId, Delvsosalesdocument, Delvsosalesdocumentitem,
          Delvsosalesorg, Delvsosoldto, Delvsoscenario,
          Delvsocurrency, Delvsonetamount, Delvremainingamount, Delvdocdate
        from ZI_OPENIO_STAGING_ROWS
        where Delvremainingamount > 0
      );

*    -- -------------------------------------------------------------------------
*    -- Step 3: Cross-join both sides and keep only overlapping pairs.
*    --
*    --   Prepay band:   |----[lo_p=====hi_p]----|
*    --   Delivery band: |--------[lo_d=====hi_d]--|
*    --   Overlap:                [lo_d===hi_p]
*    --   Formula:  MIN(hi_p, hi_d) - MAX(lo_p, lo_d)  > 0   overlap exists
*    --
*    -- This replicates the iterative FIFO drain exactly:
*    --   - A delivery item maps to every prepay item whose band it overlaps.
*    --   - The allocated amount equals the width of that overlap.
*    --   - Pairs that don't overlap are eliminated by the WHERE clause.
*    -- -------------------------------------------------------------------------
    return
      select
        p.rclnt,
*        SYSUUID AS SAPUUID,
        SUBSTR( HASH_SHA256( TO_VARBINARY( p.SessionId || '|' || p.Prepaymentso || '|' || p.Prepaymentsoitem || '|' || d.Delvsosalesdocument || '|' || d.Delvsosalesdocumentitem  ) ), 1, 16 ) AS SAPUUID,
        p.SessionId as SESSIONID,
        p.PrepaymentReqNumPrepayment as PREPAYMENTREQNUMPREPAYMENT,
        p.Prepaymentso as PREPAYMENTSO,
        p.Prepaymentsoitem as PREPAYMENTSOITEM,
        p.Prepaymentsalesorg as PREPAYMENTSALESORG,
        p.Prepaymentsoldto as PREPAYMENTSOLDTO,
        p.Prepaymentscenariopy as PREPAYMENTSCENARIOPY,
        p.Prepaymentcurrency as PREPAYMENTCURRENCY,
        p.Prepaymentnetamount as PREPAYMENTNETAMOUNT,
*        p.Prepaymentremainingamount as PREPAYMENTREMAININGAMOUNT,
        p.cum_prepay_hi - greatest( p.cum_prepay_lo, d.cum_delv_lo ) as PREPAYMENTREMAININGAMOUNT,
        p.Prepaydocdate as PREPAYDOCDATE,
        d.Delvsosalesdocument as DELVSOSALESDOCUMENT,
        d.Delvsosalesdocumentitem as DELVSOSALESDOCUMENTITEM,
        d.Delvsosalesorg as DELVSOSALESORG,
        d.Delvsosoldto as DELVSOSOLDTO,
        d.Delvsoscenario as DELVSOSCENARIO,
        d.Delvsocurrency as DELVSOCURRENCY,
        d.Delvsonetamount      as DELVSONETAMOUNT,
*        d.Delvremainingamount as DELVREMAININGAMOUNT,
        d.cum_delv_hi - greatest( p.cum_prepay_lo, d.cum_delv_lo ) as DELVREMAININGAMOUNT,
        d.Delvdocdate    as DELVDOCDATE,
        -- allocated amount = width of the overlap between the two bands
        least(   p.cum_prepay_hi, d.cum_delv_hi )
        - greatest( p.cum_prepay_lo, d.cum_delv_lo ) as DELVSOAMOUNT_ADJ
      from :lv_prepay_ranked as p
      cross join :lv_delv_ranked as d
      -- only pairs whose bands actually overlap on the money axis
      where p.Prepaymentsoldto = d.Delvsosoldto
          and p.SessionId = d.SessionId
          and p.Prepaymentcurrency = d.Delvsocurrency
          and least(   p.cum_prepay_hi, d.cum_delv_hi )
          > greatest( p.cum_prepay_lo, d.cum_delv_lo )
      order by
        d.Delvdocdate                          asc,
        d.Delvsosalesdocument                       asc,
        cast( d.Delvsosalesdocumentitem as integer ) asc,
        p.Prepaydocdate                    asc,
        p.Prepaymentso                              asc,
        cast( p.Prepaymentsoitem as integer )        asc;

  ENDMETHOD.
ENDCLASS.
