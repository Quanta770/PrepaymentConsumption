CLASS zcl_journalentry_prepayment DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
   INTERFACES if_oo_adt_classrun .
    INTERFACES if_rap_query_provider.


    TYPES: gty_je     TYPE TABLE FOR REPORTED LATE i_journalentrytp,
           gty_result TYPE STANDARD TABLE OF ZC_DELIVERY_SO_POSTING .
  PROTECTED SECTION.
  PRIVATE SECTION.
   DATA: gt_posted                  TYPE gty_je,
          gt_entry                   TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          gv_salesorder              TYPE i_salesorder-salesorder,
          gv_salesorderitem          TYPE i_salesorderitem-salesorderitem,
          gv_revenuecogsindicator(1) TYPE c,
          gv_iscorrection(1)         TYPE c,
          gv_postingdate             TYPE d,
          gv_revenueindicator(1)     TYPE c,
          gv_cogsindicator(1)        TYPE c,
          gv_interco(1)              TYPE c,
          gt_return                  TYPE STANDARD TABLE OF zta_logs.

    DATA: gv_date TYPE d,
          gv_time TYPE t.
    METHODS:
      postJournalEntry
        IMPORTING it_filters     TYPE if_rap_query_filter=>tt_name_range_pairs OPTIONAL
        RETURNING VALUE(rt_data) TYPE gty_je.

     METHODS convert_to_correct_amount
      IMPORTING iv_amount        TYPE zi_prepayment_delivery_so-DelvSoAmount
                iv_currency      TYPE waers
      RETURNING VALUE(rv_result) TYPE zi_prepayment_delivery_so-DelvSoAmount.
ENDCLASS.



CLASS ZCL_JOURNALENTRY_PREPAYMENT IMPLEMENTATION.


 METHOD convert_to_correct_amount.

    SELECT SINGLE FROM i_currency WITH PRIVILEGED ACCESS
        FIELDS decimals
        WHERE currency = @iv_currency
        INTO @DATA(lv_decimal).

    rv_result = SWITCH #( lv_decimal WHEN 0 THEN iv_amount / 100 ELSE iv_amount ).

  ENDMETHOD.


 METHOD if_oo_adt_classrun~main.
    DATA lt_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.


    DATA(lt_result) = postJournalEntry( it_filters = lt_ranges ).
    IF gt_return IS NOT INITIAL.
      out->write( gt_return ).
    ELSE.
      out->write( lt_result ).
    ENDIF.
  ENDMETHOD.


  METHOD if_rap_query_provider~select.

    DATA: gt_result TYPE STANDARD TABLE OF ZC_DELIVERY_SO_POSTING .

    DATA(top)     = io_request->get_paging( )->get_page_size( ).
    DATA(skip)    = io_request->get_paging( )->get_offset( ).
    DATA(requested_fields)  = io_request->get_requested_elements( ).
    DATA(sort_order)    = io_request->get_sort_elements( ).

    TRY.

        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).


        gt_posted = postJournalEntry( it_filters = lt_ranges ).
        IF gt_posted IS NOT INITIAL.
          LOOP AT gt_posted INTO DATA(ls_posted).

            gt_result = VALUE #(  BASE gt_result (
                accountingdocument = ls_posted-accountingdocument

            ) ).
          ENDLOOP.
*        ELSE.
*          gt_result = VALUE #(  BASE gt_result (
*                remarks = VALUE #( gt_return[ 1 ]-remarks OPTIONAL )
*            ) ).
        ENDIF.
        io_response->set_data( gt_result ).

        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( gt_result ) ).
        ENDIF.
      CATCH cx_root INTO DATA(exception).
        DATA(lv_exception_message) = cl_message_helper=>get_latest_t100_exception( exception )->if_message~get_longtext( ).
    ENDTRY.


  ENDMETHOD.


  METHOD postJournalEntry.

    DATA: ls_entry  LIKE LINE OF gt_entry,
          lv_itemno TYPE n LENGTH 6.
    DATA: lt_entry TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          lo_msg   TYPE REF TO if_abap_behv_message.

    CONSTANTS: lc_documenttype        TYPE i_journalentry-accountingdocumenttype VALUE 'AD',
               lc_transactiontype     TYPE i_journalentry-businesstransactiontype VALUE 'RFBU',
               lc_documentreferenceid TYPE i_journalentry-documentreferenceid VALUE 'BKPFF'.
    DATA(lv_salesorder) = VALUE #( it_filters[ name = 'DELVSOSALESDOCUMENT' ]-range[ 1 ]-low OPTIONAL ).
    gv_salesorder = |{ lv_salesorder ALPHA = IN }|.
    gv_salesorderitem = VALUE #( it_filters[ name = 'DELVSOSALESDOCUMENTITEM' ]-range[ 1 ]-low OPTIONAL ).
    "gv_revenuecogsindicator = VALUE #( it_filters[ name = 'REVENUECOGSINDICATOR' ]-range[ 1 ]-low OPTIONAL ).
    gv_postingdate = VALUE #( it_filters[ name = 'POSTINGDATE' ]-range[ 1 ]-low OPTIONAL ).
    "gv_iscorrection = VALUE #( it_filters[ name = 'ISCORRECTION' ]-range[ 1 ]-low OPTIONAL ).
    gv_date = cl_abap_context_info=>get_system_date( ).
    gv_time = cl_abap_context_info=>get_system_time( ).

SELECT
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTREQNUMPREPAYMENT,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTSO,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTSOITEM,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTSALESORG,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTSOLDTO,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTSCENARIOPY,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTSDITEMCTGY,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTCURRENCY,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTGROSSAMOUNT,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTCTRDWNPAYMNT,
   ZC_PREPAYMENT_DELIVERY_SO~PREPAYMENTREQNUM,
   ZC_PREPAYMENT_DELIVERY_SO~DELVSOSALESDOCUMENT,
   ZC_PREPAYMENT_DELIVERY_SO~DELVSOSALESDOCUMENTITEM,
   ZC_PREPAYMENT_DELIVERY_SO~DELVSOSALESORG,
   ZC_PREPAYMENT_DELIVERY_SO~DELVSOSOLDTO,
   ZC_PREPAYMENT_DELIVERY_SO~DELVSOSCENARIO,
   ZC_PREPAYMENT_DELIVERY_SO~DELVSOSDITMCTGY,
   ZC_PREPAYMENT_DELIVERY_SO~DELVSOCURRENCY,
   ZC_PREPAYMENT_DELIVERY_SO~DELVSOAMOUNT

 FROM
  ZC_PREPAYMENT_DELIVERY_SO
  where DELVSOSALESDOCUMENT = @gv_salesorder
  and DELVSOSALESDOCUMENTITEM = @gv_salesorderitem
    into table @data(lt_Delivery_SO).

    LOOP AT lt_Delivery_SO INTO DATA(ls_Delivery_SO).

      "Header
      DATA(lo_generator) = cl_uuid_factory=>create_system_uuid( ).
      TRY.
          ls_entry-%cid = lo_generator->create_uuid_x16( ).
        CATCH cx_uuid_error ##NO_HANDLER.
      ENDTRY.
      "ls_entry-%param-companycode = ls_Delivery_SO-companycode.
      ls_entry-%param-companycode = ls_Delivery_SO-DelvSoSalesOrg.
      "ls_entry-%param-accountingdocumentheadertext = |{ lv_app_indicator } Posting - { gv_date }|.
      ls_entry-%param-documentdate = gv_date.
      ls_entry-%param-postingdate = gv_postingdate.
      ls_entry-%param-taxdeterminationdate = gv_date.
      ls_entry-%param-createdbyuser = sy-uname.
      ls_entry-%param-businesstransactiontype = lc_transactiontype.
      ls_entry-%param-documentreferenceid = lc_documentreferenceid.
      ls_entry-%param-accountingdocumenttype = lc_documenttype.
      "Items

      lv_itemno = lv_itemno + 1.


      ls_entry-%param-_glitems = VALUE #( LET lv_transaction_amount = convert_to_correct_amount(
                                                                        iv_amount   = ls_Delivery_SO-DelvSoAmount
                                                                        iv_currency = ls_Delivery_SO-DelvSoCurrency )

        IN BASE ls_entry-%param-_glitems (
       " yy1_revcogsindicator_cob = ls_Delivery_SO-revenuecogsindicator
        glaccountlineitem = lv_itemno
        glaccount         = |{ '2107010200' ALPHA = IN }|
        wbselement = 'SAC1-AME-SAL-LOCL'
*            wbselement        = SWITCH #( ls_Delivery_SO-revenuecogsindicator
*                                      WHEN gc_c "COGS
*                                        THEN ls_data-wbs
*                                      ELSE COND #( WHEN ls_Delivery_SO-glaccount(1) EQ '1'
*                                                    THEN ls_data-wbs
*                                                   ELSE '' )
*                                )
*            profitcenter      = SWITCH #( ls_Delivery_SO-entity
*                                    WHEN gc_buyer THEN 'ALEPH'
*                                    ELSE ls_data-profitcenter ) "Seller
*            costcenter        = SWITCH #( ls_Delivery_SO-entity
*                                    WHEN gc_buyer THEN ls_header-item-companycode
*                                    ELSE '' )   "Seller
        profitcenter  = 'ALEPH'
        costcenter = ''
     "   documentitemtext  = |{ lv_app_indicator } Item { ls_Delivery_SO-journallineitem ALPHA = OUT }|
        salesorder = |{ ls_Delivery_SO-DelvSoSalesDocument ALPHA = IN }|
        salesorderitem = |{ ls_Delivery_SO-DelvSoSalesDocumentItem ALPHA = IN }|
*            functionalarea = ls_data-reportingentity
*            PartnerCompany = ls_Delivery_SO-TradingPartner
        _profitabilitysupplement-customer = ls_Delivery_SO-DelvSoSoldTO
        _profitabilitysupplement-salesorder = |{ ls_Delivery_SO-DelvSoSalesDocument ALPHA = IN }|
        _profitabilitysupplement-salesorderitem = |{ ls_Delivery_SO-DelvSoSalesDocumentItem ALPHA = IN }|
*            _profitabilitysupplement-wbselement = SWITCH #( ls_Delivery_SO-revenuecogsindicator
*                                                      WHEN 'C' THEN ''
*                                                      ELSE COND #(
*                                                        WHEN ls_Delivery_SO-glaccount(1) NE '1'
*                                                            THEN ls_data-wbs
*                                                        ELSE '' )
*                                                  )

         AssignmentReference = |{ ls_Delivery_SO-DelvSoSalesDocument ALPHA = IN }| &   |{ ls_Delivery_SO-DelvSoSalesDocumentitem ALPHA = IN }|

        _currencyamount = VALUE #( (
            currencyrole = '00'
            currency = ls_Delivery_SO-DelvSoCurrency
            journalentryitemamount = SWITCH #( 'S'
                  WHEN 'H' THEN lv_transaction_amount * -1
                  ELSE lv_transaction_amount )

         ) )

       ) ).
*          "change WBS of Buying entity for COGS
*          IF ls_Delivery_SO-entity EQ gc_buyer.
*
*            ASSIGN ls_entry-%param-_glitems[ lv_itemno ] TO FIELD-SYMBOL(<ls_item>).
*            IF sy-subrc = 0.
*              IF <ls_item>-wbselement IS NOT INITIAL AND <ls_item>-wbselement(4) NE ls_header-item-companycode.
*                <ls_item>-wbselement(4) = ls_header-item-companycode.
*              ENDIF.
*              IF <ls_item>-_profitabilitysupplement-wbselement IS NOT INITIAL AND <ls_item>-_profitabilitysupplement-wbselement(4) NE ls_header-item-companycode.
*                <ls_item>-_profitabilitysupplement-wbselement(4) = ls_header-item-companycode.
*              ENDIF.
*            ENDIF.
*
*          ENDIF.
      APPEND ls_entry TO gt_entry.
      CLEAR:  ls_entry,
              lv_itemno,
              ls_Delivery_SO.

    ENDLOOP.

* post Journal entries
    IF gt_entry IS NOT INITIAL.
      MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
        ENTITY journalentry
        EXECUTE post FROM gt_entry
        MAPPED FINAL(ls_post_mapped)
        FAILED FINAL(ls_post_failed)
        REPORTED FINAL(ls_post_reported).

    IF sy-subrc = 0.

    loop at ls_post_mapped-journalentry into data(ls_accounting).
*   APPEND VALUE #( accountingdocument = ls_accounting-accountingDocument ) TO result.
    endloop.
    ENDIF.
   endif.
  ENDMETHOD.
ENDCLASS.
