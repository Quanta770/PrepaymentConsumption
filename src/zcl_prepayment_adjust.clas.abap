CLASS zcl_prepayment_adjust DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES: if_amdp_marker_hdb.
    CLASS-METHODS: amount_to_adjust FOR TABLE FUNCTION zi_amount_to_adjust.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PREPAYMENT_ADJUST IMPLEMENTATION.


  METHOD amount_to_adjust BY DATABASE FUNCTION FOR HDB
         LANGUAGE SQLSCRIPT
         OPTIONS READ-ONLY
         USING zi_prepayment_delivery_so_int.


*    lv_agr_amt1 = select session_context('CLIENT')  AS rclnt,
*                    prepaymentreqnumprepayment ,
*                    prepaymentso ,
*                    prepaymentsoitem ,
*                    prepaymentsalesorg ,
*                    max(prepaymentremainingamount) as prepaymentnetamount ,
*                    max( delvsosalesdocument ) as delvsosalesdocument, --Updated by derek
*                    max( delvsosalesdocumentitem ) as delvsosalesdocumentitem, --Updated by derek
*                    sum( delvnetamount ) as delvtotal,
*                    sum( delvnetamount  ) as delvsoamount,
*                    count( delvsosalesdocument ) as NumLines
*      from  zi_prepayment_delivery_so_int
*      where prepaymentreqnumprepayment = prepaymentreqnum
*
*
**  and   prepaymentreqnumprepayment = :ip_prepaynum
**        and delvsosalesdocument        = :ip_salesdoc
**        and delvsosalesdocumentitem    = :ip_salesitem
*      group by prepaymentreqnumprepayment,prepaymentso , prepaymentsoitem ,prepaymentsalesorg ;
******Start of changes 09/01
*    lv_agr_amt = SELECT tb1.rclnt,
*                    tb1.prepaymentreqnumprepayment ,
*                    tb1.prepaymentso ,
*                    tb1.prepaymentsoitem ,
*                    tb1.prepaymentsalesorg ,
*                    tb1.prepaymentnetamount,
*                    tb2.delvsosalesdocument,
*                    tb2.delvsosalesdocumentitem,
*                    tb1.delvtotal,
*                    tb1.delvsoamount,
*                    'X' as adj_flag,
*                    tb1.NumLines,
*                    tb1.delvsosalesdocumentitem as adj_item
*                    from :lv_agr_amt1 as tb1
*                    left outer join zi_prepayment_delivery_so_int as tb2
*                    on tb1.prepaymentreqnumprepayment = tb2.prepaymentreqnumprepayment
*                    and tb1.delvsosalesdocument = tb2.delvsosalesdocument
*                    and tb1.delvsosalesdocumentitem = tb2.delvsosalesdocumentitem;
*
******End   of changes 09/01
*    lv_over_delvamt = select session_context('CLIENT')  as rclnt,
*                    prepaymentreqnumprepayment ,
*                    prepaymentso ,
*                    prepaymentsoitem ,
*                    prepaymentsalesorg ,
*                    prepaymentnetamount ,
*                    delvsoamount ,
*                    delvsosalesdocument,
*                    delvsosalesdocumentitem,
*                    coalesce( prepaymentnetamount,0 ) - coalesce( delvsoamount,0 ) as overdelvamt,
*                    adj_flag,
*                    NumLines,
*                    adj_item
*      from   :lv_agr_amt  ;
*
*    lv_over_delv1 = select session_context('CLIENT')  as rclnt,
*                    tb1.prepaymentreqnumprepayment ,
*                    tb1.sourcetype ,
*                    tb1.prepaymentso ,
*                    tb1.prepaymentsoitem ,
*                    tb1.prepaymentsalesorg ,
*                    tb1.prepaymentsoldto ,
*                    tb1.prepaymentscenariopy ,
*                    tb1.prepaymentsditemctgy ,
*                    tb1.prepaymentcurrency ,
*                    tb1.prepaymentnetamount ,
*                    tb1.prepaymentremainingamount ,
*                    tb1.prepaymentctrdwnpaymnt ,
*                    tb1.prepaymentreqnum ,
*                    tb1.delvsosalesdocument ,
*                    tb1.delvsosalesdocumentitem ,
*                    tb1.delvsosalesorg ,
*                    tb1.delvsosoldto ,
*                    tb1.delvsoscenario ,
*                    tb1.delvsosditmctgy ,
*                    tb1.delvsocurrency ,
*                    tb1.delvnetamount ,
*                    tb1.delvremainingamount,
*                    tb2.overdelvamt,
*                    tb2.adj_flag,
*                    tb2.NumLines,
*                    tb2.adj_item,
*                    case when tb2.adj_item = tb1.delvsosalesdocumentitem
*                         then 'X'
*                         else '' end as SRT_FLG
*      from  zi_prepayment_delivery_so_int as tb1
*      left outer join :lv_over_delvamt as tb2
*      on tb1.prepaymentreqnumprepayment = tb2.prepaymentreqnumprepayment
*       and  tb1.delvsosalesdocument = tb2.delvsosalesdocument --Updated by derek
*       and tb1.delvsosalesdocumentitem = tb2.delvsosalesdocumentitem ;

*lv_temp_res = select rclnt,
*                    prepaymentreqnumprepayment ,
*                    sourcetype ,
*                    prepaymentso ,
*                    prepaymentsoitem ,
*                    prepaymentsalesorg ,
*                    prepaymentsoldto ,
*                    prepaymentscenariopy ,
*                    prepaymentsditemctgy ,
*                    prepaymentcurrency ,
*                    prepaymentnetamount ,
*                    prepaymentremainingamount ,
*                    prepaymentctrdwnpaymnt ,
*                    prepaymentreqnum ,
*                    delvsosalesdocument ,
*                    delvsosalesdocumentitem ,
*                    delvsosalesorg ,
*                    delvsosoldto ,
*                    delvsoscenario ,
*                    delvsosditmctgy ,
*                    delvsocurrency ,
*                    delvnetamount  as delvsonetamount,
*                    delvremainingamount,
*                    SRT_FLG,
*                    -- Updated 25/11/2025
*                    greatest ( case when NumLines > 1
*                    then (CASE when delvsosalesdocumentitem = adj_item then
*                          least(delvremainingamount, prepaymentremainingamount) + coalesce(overdelvamt,0)
*                          ELSE delvremainingamount end)
*                   ELSE
*                   (CASE when delvremainingamount  > prepaymentremainingamount
*                   then prepaymentremainingamount
*                   ELSE delvremainingamount END ) END, 0 ) as delvsoamount_adj
*      from :lv_over_delv1 group by rclnt, prepaymentreqnumprepayment,  delvsosalesdocument ,
*                    delvsosalesdocumentitem  ,
*                      sourcetype ,
*                    prepaymentso ,
*                    prepaymentsoitem ,
*                    prepaymentsalesorg ,
*                    prepaymentsoldto ,
*                    prepaymentscenariopy ,
*                    prepaymentsditemctgy ,
*                    prepaymentcurrency ,
*                    prepaymentnetamount ,
*                    prepaymentremainingamount ,
*                    prepaymentctrdwnpaymnt ,
*                    prepaymentreqnum ,
*                    delvsosalesdocument ,
*                    delvsosalesdocumentitem ,
*                    delvsosalesorg ,
*                    delvsosoldto ,
*                    delvsoscenario ,
*                    delvsosditmctgy ,
*                    delvsocurrency ,
*                    delvnetamount  ,
*                    delvremainingamount,
*                    NumLines,adj_item,overdelvamt,SRT_FLG
*                    order by  SRT_FLG DESC;

-- New block
    lv_sorted =
      select
        session_context('CLIENT') as rclnt,
        prepaymentreqnumprepayment,
        sourcetype,
        prepaymentso,
        prepaymentsoitem,
        prepaymentsalesorg,
        prepaymentsoldto,
        prepaymentscenariopy,
        prepaymentsditemctgy,
        prepaymentcurrency,
        prepaymentnetamount,
        prepaymentremainingamount,
        prepaymentctrdwnpaymnt,
        prepaymentreqnum,
        delvsosalesdocument,
        delvsosalesdocumentitem,
        delvsosalesorg,
        delvsosoldto,
        delvsoscenario,
        delvsosditmctgy,
        delvsocurrency,
        delvnetamount,
        delvremainingamount,
        -- partition-level prepayment remaining (same value for all rows in the prepayment group)
        max(prepaymentremainingamount)
          over (partition by prepaymentreqnumprepayment) as prepay_remaining_partition,
        -- cumulative delivery ordered by item (numerical order). cast to integer in case item is stored with leading zeros.
        sum( delvremainingamount )
          over (
            partition by prepaymentreqnumprepayment
            order by cast( delvsosalesdocumentitem as integer )
            rows between unbounded preceding and current row
          ) as cum_delv
      from zi_prepayment_delivery_so_int
      where prepaymentreqnumprepayment = prepaymentreqnum   -- preserve original input filter if any
      order by prepaymentreqnumprepayment, cast( delvsosalesdocumentitem as integer );

      -- Step: compute FIFO AmountToApply (delvsoamount_adj) using cumulative sums ---
        lv_fifo_applied =
          select
            rclnt,
            prepaymentreqnumprepayment,
            sourcetype,
            prepaymentso,
            prepaymentsoitem,
            prepaymentsalesorg,
            prepaymentsoldto,
            prepaymentscenariopy,
            prepaymentsditemctgy,
            prepaymentcurrency,
            prepaymentnetamount,
            prepaymentremainingamount,
            prepaymentctrdwnpaymnt,
            prepaymentreqnum,
            delvsosalesdocument,
            delvsosalesdocumentitem,
            delvsosalesorg,
            delvsosoldto,
            delvsoscenario,
            delvsosditmctgy,
            delvsocurrency,
            delvnetamount,
            delvremainingamount,
            prepay_remaining_partition,
            cum_delv,
            -- FIFO amount to apply:
            greatest(
              case
                -- fully covered by prepayment: cumulative upto current <= prepayment => apply full current line
                when cum_delv <= prepay_remaining_partition
                  then delvremainingamount
                -- fully after prepayment exhaustion: cumulative before current >= prepayment => apply 0
                when (cum_delv - delvremainingamount) >= prepay_remaining_partition
                  then 0
                -- partially covered: apply the remaining prepayment that reaches into this row
                else prepay_remaining_partition - (cum_delv - delvremainingamount)
              end
            , 0) as delvsoamount_adj
          from :lv_sorted
          order by prepaymentreqnumprepayment, cast( delvsosalesdocumentitem as integer );

      Return
      select
        rclnt,
        prepaymentreqnumprepayment,
        sourcetype,
        prepaymentso,
        prepaymentsoitem,
        prepaymentsalesorg,
        prepaymentsoldto,
        prepaymentscenariopy,
        prepaymentsditemctgy,
        prepaymentcurrency,
        prepaymentnetamount,
        prepaymentremainingamount,
        prepaymentctrdwnpaymnt,
        prepaymentreqnum,
        delvsosalesdocument,
        delvsosalesdocumentitem,
        delvsosalesorg,
        delvsosoldto,
        delvsoscenario,
        delvsosditmctgy,
        delvsocurrency,
        delvnetamount as delvsonetamount,
        delvremainingamount,
        delvsoamount_adj
      from :lv_fifo_applied
      order by prepaymentreqnumprepayment, cast( delvsosalesdocumentitem as integer );
*
*      Return select rclnt,
*                    prepaymentreqnumprepayment ,
*                    sourcetype ,
*                    prepaymentso ,
*                    prepaymentsoitem ,
*                    prepaymentsalesorg ,
*                    prepaymentsoldto ,
*                    prepaymentscenariopy ,
*                    prepaymentsditemctgy ,
*                    prepaymentcurrency ,
*                    prepaymentnetamount ,
*                    prepaymentremainingamount ,
*                    prepaymentctrdwnpaymnt ,
*                    prepaymentreqnum ,
*                    delvsosalesdocument ,
*                    delvsosalesdocumentitem ,
*                    delvsosalesorg ,
*                    delvsosoldto ,
*                    delvsoscenario ,
*                    delvsosditmctgy ,
*                    delvsocurrency ,
*                    delvsonetamount,
*                    delvremainingamount,
**                case when OVERDELVAMT < 0
**                      then DELVSOAMOUNT - coalesce(abs(OVERDELVAMT),0)
**                      else DELVSOAMOUNT - coalesce(OVERDELVAMT,0) end
**                 as DELVSOAMOUNT_ADJ
**                case when ADJ_FLAG = 'X' and OVERDELVAMT < 0
**                     then DELVNETAMOUNT - coalesce(abs(OVERDELVAMT),0)
***                     else DELVNETAMOUNT END as DELVSOAMOUNT_ADJ
**                     else DELVREMAININGAMOUNT END as DELVSOAMOUNT_ADJ
**               least(DELVREMAININGAMOUNT ,PREPAYMENTREMAININGAMOUNT )
**               + coalesce(OVERDELVAMT,0)
*                 delvsoamount_adj
*      from :lv_temp_res group by rclnt, prepaymentreqnumprepayment,  delvsosalesdocument ,
*                    delvsosalesdocumentitem  ,
*                      sourcetype ,
*                    prepaymentso ,
*                    prepaymentsoitem ,
*                    prepaymentsalesorg ,
*                    prepaymentsoldto ,
*                    prepaymentscenariopy ,
*                    prepaymentsditemctgy ,
*                    prepaymentcurrency ,
*                    prepaymentnetamount ,
*                    prepaymentremainingamount ,
*                    prepaymentctrdwnpaymnt ,
*                    prepaymentreqnum ,
*                    delvsosalesdocument ,
*                    delvsosalesdocumentitem ,
*                    delvsosalesorg ,
*                    delvsosoldto ,
*                    delvsoscenario ,
*                    delvsosditmctgy ,
*                    delvsocurrency ,
*                    delvsonetamount  ,
*                    delvremainingamount,
*                    delvsoamount_adj,
*                    SRT_FLG
*                    order by  delvsoamount_adj DESC
*
*                     ;
  ENDMETHOD.
ENDCLASS.
