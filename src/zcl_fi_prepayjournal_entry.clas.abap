CLASS zcl_fi_prepayjournal_entry DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
    INTERFACES if_rap_query_provider.
    DATA: gt_entry1 TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          lt_entry  LIKE LINE OF gt_entry1.
    TYPES: ty_je_create_line TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
           ty_glitem         TYPE LINE OF ty_je_create_line.
    TYPES: gty_je     TYPE TABLE FOR REPORTED LATE i_journalentrytp,
           gty_result TYPE STANDARD TABLE OF zi_prepaypost_custom_ent.
    TYPES ty_post_result TYPE TABLE OF za_jepost_result WITH EMPTY KEY.
    METHODS PrepayPost
      IMPORTING it_filters       TYPE if_rap_query_filter=>tt_name_range_pairs OPTIONAL
      RETURNING VALUE(rt_result) TYPE ty_post_result.
*      RETURNING VALUE(rt_data) TYPE gty_je.

    METHODS convert_to_correct_amount
      IMPORTING iv_amount        TYPE zi_prepayment_delivery_so-DelvSoAmount
                iv_currency      TYPE waers
      RETURNING VALUE(rv_result) TYPE zi_prepayment_delivery_so-DelvSoAmount.
    METHODS get_gl_account
      IMPORTING iv_customer     TYPE zi_prepayment_delivery_so-DelvSoSoldTO
                iv_salesorg     TYPE zi_prepayment_delivery_so-DelvSoSalesOrg
      RETURNING VALUE(rv_glacc) TYPE akont.
    METHODS fill_gl_item
      IMPORTING
        is_data        TYPE zstprepayglitem   " Structure of ls_data-item
        iv_itemno      TYPE posnr
        iv_glacc       TYPE saknr
        iv_debitcredit TYPE shkzg
        iv_scenario    TYPE zde_char01
        iv_taxcode     TYPE string OPTIONAL
      RETURNING
        VALUE(rs_item) TYPE ty_glitem. " One GL item structure
    METHODS fill_ar_item
      IMPORTING
        is_data          TYPE zstprepayglitem   " Structure of ls_data-item
        iv_itemno        TYPE posnr
        iv_glacc         TYPE saknr
        iv_debitcredit   TYPE shkzg
        iv_taxcode       TYPE string
        iv_specialglcode TYPE string OPTIONAL
      RETURNING
        VALUE(rs_item)   TYPE ty_glitem. " One GL item structures

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA: gt_posted TYPE ty_post_result,
          gt_entry  TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          gt_return TYPE STANDARD TABLE OF zi_prepaypost_custom_ent.
ENDCLASS.



CLASS ZCL_FI_PREPAYJOURNAL_ENTRY IMPLEMENTATION.


  METHOD convert_to_correct_amount.

    SELECT SINGLE FROM i_currency WITH PRIVILEGED ACCESS
        FIELDS decimals
        WHERE currency = @iv_currency
        INTO @DATA(lv_decimal).

    rv_result = SWITCH #( lv_decimal WHEN 0 THEN iv_amount / 100 ELSE iv_amount ).

  ENDMETHOD.


  METHOD fill_gl_item.

    DATA ls_glitem TYPE ty_glitem.

*    DATA(lv_transaction_amount) = convert_to_correct_amount(
*                                  iv_amount   = is_data-grossamount
*                                  iv_currency = is_data-socurrency ).
    DATA(lv_transaction_amount) = is_data-grossamount.

    IF iv_scenario = 'B'.
      rs_item-%param-_glitems = VALUE #(

              (         glaccountlineitem        = iv_itemno
                     glaccount                = |{ iv_glacc ALPHA = IN }|
                     "wbselement               = is_data-wbs

                     profitcenter             =  is_data-profitcenter
*                          costcenter               = SWITCH #( is_data-entity
*                                                        WHEN gc_buyer THEN is_header-companycode
*                                                        ELSE '' )
                     documentitemtext         = |Item { iv_itemno ALPHA = OUT }|
                     salesorder               = |{ is_data-salesorder ALPHA = IN }|
                     salesorderitem           = |{ is_data-salesorderitem ALPHA = IN }|
                     functionalarea           = is_data-salesorg
*                          partnercompany = is_data-TradingPartner

                     _profitabilitysupplement-customer        = is_data-soldto
                     _profitabilitysupplement-salesorder      = |{ is_data-salesorder ALPHA = IN }|
                     _profitabilitysupplement-salesorderitem  = |{ is_data-salesorderitem ALPHA = IN }|
                     "_profitabilitysupplement-wbselement      =  is_data-wbs

                     assignmentreference = |{ is_data-salesorder ALPHA = IN }|
                                           && |{ is_data-salesorderitem ALPHA = IN }|

                     _currencyamount = VALUE #( ( currencyrole           = '00'
                                                  currency               = is_data-socurrency
                                                  journalentryitemamount = SWITCH #( iv_debitcredit
                                                                                     WHEN 'H' THEN lv_transaction_amount * -1
                                                                                   ELSE lv_transaction_amount ) ) ) ) ).
    ELSEIF iv_scenario = 'C' or iv_scenario = 'D1'.
      rs_item-%param-_glitems = VALUE #(

               (         glaccountlineitem        = iv_itemno
                      glaccount                = |{ iv_glacc ALPHA = IN }|
                      "wbselement               = is_data-wbs

                      profitcenter             =  is_data-profitcenter
*                          costcenter               = SWITCH #( is_data-entity
*                                                        WHEN gc_buyer THEN is_header-companycode
*                                                        ELSE '' )
                      documentitemtext         = |Item { iv_itemno ALPHA = OUT }|
                      salesorder               = |{ is_data-salesorder ALPHA = IN }|
                      salesorderitem           = |{ is_data-salesorderitem ALPHA = IN }|
                      taxcode                  = |{ iv_taxcode }|
                      functionalarea           = is_data-salesorg
*                          partnercompany = is_data-TradingPartner

                      _profitabilitysupplement-customer        = is_data-soldto
                      _profitabilitysupplement-salesorder      = |{ is_data-salesorder ALPHA = IN }|
                      _profitabilitysupplement-salesorderitem  = |{ is_data-salesorderitem ALPHA = IN }|
                      "_profitabilitysupplement-wbselement      =  is_data-wbs

                      assignmentreference = |{ is_data-salesorder ALPHA = IN }|
                                            && |{ is_data-salesorderitem ALPHA = IN }|

                      _currencyamount = VALUE #( ( currencyrole           = '00'
                                                   currency               = is_data-socurrency
                                                   journalentryitemamount = SWITCH #( iv_debitcredit
                                                                                      WHEN 'H' THEN lv_transaction_amount * -1
                                                                                    ELSE lv_transaction_amount ) ) ) ) ).
    ELSEIF  iv_scenario = 'A'.
      rs_item-%param-_glitems = VALUE #(

            (         glaccountlineitem        = iv_itemno
                   glaccount                = |{ iv_glacc ALPHA = IN }|
                   wbselement               = is_data-wbs

                   profitcenter             =  is_data-profitcenter
*                          costcenter               = SWITCH #( is_data-entity
*                                                        WHEN gc_buyer THEN is_header-companycode
*                                                        ELSE '' )
                   documentitemtext         = |Item { iv_itemno ALPHA = OUT }|
                   salesorder               = |{ is_data-salesorder ALPHA = IN }|
                   salesorderitem           = |{ is_data-salesorderitem ALPHA = IN }|
                   taxcode                  = |{ iv_taxcode }|
                   functionalarea           = is_data-salesorg
*                          partnercompany = is_data-TradingPartner

                   _profitabilitysupplement-customer        = is_data-soldto
                   _profitabilitysupplement-salesorder      = |{ is_data-salesorder ALPHA = IN }|
                   _profitabilitysupplement-salesorderitem  = |{ is_data-salesorderitem ALPHA = IN }|
                   _profitabilitysupplement-wbselement      =  is_data-wbs

                   assignmentreference = |{ is_data-salesorder ALPHA = IN }|
                                         && |{ is_data-salesorderitem ALPHA = IN }|

                   _currencyamount = VALUE #( ( currencyrole           = '00'
                                                currency               = is_data-socurrency
                                                journalentryitemamount = SWITCH #( iv_debitcredit
                                                                                   WHEN 'H' THEN lv_transaction_amount * -1
                                                                                 ELSE lv_transaction_amount ) ) ) ) ).

    ENDIF.


  ENDMETHOD.


  METHOD fill_ar_item.

    DATA ls_aritem TYPE ty_glitem.

*    DATA(lv_transaction_amount) = convert_to_correct_amount(
*                                  iv_amount   = is_data-grossamount
*                                  iv_currency = is_data-socurrency ).
    DATA(lv_transaction_amount) = is_data-grossamount.

    rs_item-%param-_aritems = VALUE #(

            (
                   glaccountlineitem        = iv_itemno
                   glaccount                = |{ iv_glacc ALPHA = IN }|
                   "wbselement               = is_data-wbs

                   customer             =  |{ is_data-soldto }|
*                      costcenter               = SWITCH #( is_data-entity
*                                                    WHEN gc_buyer THEN is_header-companycode
*                                                    ELSE '' )
                   salesorder               = |{ is_data-salesorder ALPHA = IN }|
                   salesorderitem           = |{ is_data-salesorderitem ALPHA = IN }|
                   taxcode               = |{ iv_taxcode }|
                   "salesorderitem           = |{ is_data-salesorderitem ALPHA = IN }|
                   "functionalarea           = is_data-salesorg
*                      partnercompany = is_data-TradingPartner
                    SpecialGLCode       = iv_specialglcode
                   assignmentreference = |{ is_data-salesorder ALPHA = IN }|
                                         && |{ is_data-salesorderitem ALPHA = IN }|

                   _currencyamount = VALUE #( ( currencyrole           = '00'
                                                currency               = is_data-socurrency
                                                journalentryitemamount = SWITCH #( iv_debitcredit
                                                                                   WHEN 'H' THEN lv_transaction_amount * -1
                                                                                   ELSE lv_transaction_amount ) ) ) ) ).




  ENDMETHOD.


  METHOD PrepayPost.

    DATA: ls_entry  LIKE LINE OF gt_entry,
          lv_itemno TYPE n LENGTH 6.
    DATA: lt_entry TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          lo_msg   TYPE REF TO if_abap_behv_message.
    DATA: gv_date  TYPE d,
          gv_time  TYPE t,
          lv_glacc TYPE saknr.
    DATA: ls_text(200)    TYPE c.
    DATA: lv_all_messages TYPE string.
    CONSTANTS: lc_documenttype        TYPE i_journalentry-accountingdocumenttype VALUE 'AD',
               lc_transactiontype     TYPE i_journalentry-businesstransactiontype VALUE 'RFBU',
               lc_documentreferenceid TYPE i_journalentry-documentreferenceid VALUE 'BKPFF'.

*    DATA: lt_data_prv TYPE table for read RESULT ZC_PREPAYMENT_PREVIEW ,
*          ls_data_prv type zi_preview_result.
    DATA: lt_data_tmp  TYPE STANDARD TABLE OF zc_prepayment_delivery_so,
          lt_result    TYPE TABLE FOR READ RESULT zc_prepayment_preview,
          ls_data_prv  LIKE LINE OF lt_result,
          ls_post_data TYPE zstprepayglitem.

    DATA: lv_journal     TYPE i,
          lv_journalitem TYPE i.
    DATA(lv_prepayNo) = VALUE #( it_filters[ name = 'PREPAYMENTREQUEST' ]-range[ 1 ]-low OPTIONAL ).
    " Start of Addition
    DATA(lv_PreOrder) = VALUE #( it_filters[ name = 'PREPAYMENTSO' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_PreOrderItem) = VALUE #( it_filters[ name = 'PREPAYMENTSOITEM' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_DlvOrder) = VALUE #( it_filters[ name = 'DELIVERYSO' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_DlvOrderItem) = VALUE #( it_filters[ name = 'DELIVERYSOITEM' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_category) = VALUE #( it_filters[ name = 'SCENARIO' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_Amounttoadjust) = VALUE #( it_filters[ name = 'AMOUNTTOAPPLY' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_prepaycurr) = VALUE #( it_filters[ name = 'PREPAYCURRENCY' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_delvcurr) = VALUE #( it_filters[ name = 'DELVCURRENCY' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_date) = VALUE #( it_filters[ name = 'PROFITCENTER' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_writeoff) = VALUE #( it_filters[ name = 'SOLDTO' ]-range[ 1 ]-low OPTIONAL ).
    " End of Addition

    SELECT DISTINCT
           zc_prepayment_delivery_so~prepaymentreqnumprepayment AS prepaymentrequest,
           zc_prepayment_delivery_so~prepaymentso AS salesorder,
           zc_prepayment_delivery_so~prepaymentsoitem AS salesorderitem,
           zc_prepayment_delivery_so~prepaymentsalesorg AS salesorg,
           zc_prepayment_delivery_so~prepaymentsoldto AS soldto,
           zc_prepayment_delivery_so~prepaymentscenariopy AS scenario,
           zc_prepayment_delivery_so~prepaymentsditemctgy AS itemctgy,
           zc_prepayment_delivery_so~prepaymentcurrency AS socurrency,
           zc_prepayment_delivery_so~prepaymentgrossamount AS grossamount,
           PrePaySO~ProfitCenter AS profitcenter,
           PrePaySO~YY1_StatWBSExt_SDI AS wbs,
           zc_prepayment_delivery_so~PrepaymentRemainingAmount,
           zc_prepayment_delivery_so~DelvRemainingAmount
      FROM
       zc_prepayment_delivery_so
       LEFT OUTER JOIN I_SalesDocumentItem AS PrePaySO
       ON zc_prepayment_delivery_so~PrepaymentSO = PrePaySo~SalesDocument
       AND zc_prepayment_delivery_so~prepaymentsoitem = PrePaySo~SalesDocumentItem
      WHERE prepaymentso = @lv_PreOrder
      AND prepaymentsoitem = @lv_PreOrderItem
        INTO TABLE @DATA(lt_data_prepay).

    IF lt_data_prepay IS INITIAL.
      APPEND VALUE #(
        Status  = 'ERROR'
        Message = |No prepayment data found for SO { lv_PreOrder ALPHA = OUT } item { lv_PreOrderItem ALPHA = OUT }|
      ) TO rt_result.
      RETURN.
    ENDIF.

    IF sy-subrc = 0.
      SELECT
           zc_prepayment_delivery_so~prepaymentreqnumprepayment,
           zc_prepayment_delivery_so~delvsosalesdocument,
           zc_prepayment_delivery_so~delvsosalesdocumentitem,
           zc_prepayment_delivery_so~delvsosalesorg,
           zc_prepayment_delivery_so~delvsosoldto,
           zc_prepayment_delivery_so~delvsoscenario,
           zc_prepayment_delivery_so~delvsosditmctgy,
           zc_prepayment_delivery_so~delvsocurrency,
           zc_prepayment_delivery_so~delvsoamount,
           zc_prepayment_delivery_so~delvnetamount,
           DelvSO~ProfitCenter AS ProfitCenter,
           DelvSO~YY1_StatWBSExt_SDI AS wbs
      FROM
       zc_prepayment_delivery_so
       LEFT OUTER JOIN I_SalesDocumentItem AS DelvSO
       ON zc_prepayment_delivery_so~delvsosalesdocument = DelvSO~SalesDocument
       AND zc_prepayment_delivery_so~delvsosalesdocumentitem = DelvSO~SalesDocumentItem
      WHERE delvsosalesdocument = @lv_DlvOrder
           AND delvsosalesdocumentitem = @lv_DlvOrderItem
        INTO TABLE @DATA(lt_data_DelvSo).
     IF lt_data_DelvSo IS INITIAL.
        APPEND VALUE #(
          Status  = 'ERROR'
          Message = |No delivery SO data found for SO { lv_DlvOrder ALPHA = OUT } item { lv_DlvOrderItem ALPHA = OUT }|
        ) TO rt_result.
        RETURN.
      ENDIF.
* Rounding Threshold from Config table
      DATA(lv_salesOrg) = VALUE #( lt_data_DelvSo[ 1 ]-DelvSoSalesOrg  OPTIONAL ).

      SELECT
         zr_config_value~uuid,
         zr_config_value~parameterid,
         zr_config_value~itemno,
         zr_config_value~category,
         zr_config_value~value1,
         zr_config_value~value2,
         zr_config_value~value3
       FROM
        zr_config_value
       WHERE
        parameterid = 'ROUNDING_THRSHD'
        INTO TABLE @DATA(lt_rounding).
      SELECT
       zr_config_value~uuid,
       zr_config_value~parameterid,
       zr_config_value~itemno,
       zr_config_value~category,
       zr_config_value~value1,
       zr_config_value~value2,
       zr_config_value~value3
     FROM
      zr_config_value
     WHERE
      parameterid = 'GLACCT_ROUNDING'
      INTO TABLE @DATA(lt_glaccrndg).
* end of rounding logic


      IF lv_category = 'B' AND sy-subrc = 0.
        " get the GL Accounts from CONFIG Table
        SELECT
           zr_config_value~uuid,
           zr_config_value~parameterid,
           zr_config_value~itemno,
           zr_config_value~category,
           zr_config_value~value1
         FROM
          zr_config_value
         WHERE
          parameterid = 'GLACCOUNT'
          INTO TABLE @DATA(lt_glacc).
        "Prepare the result of Post
        lv_journal = lv_journalitem = 1.
        gv_date = cl_abap_context_info=>get_system_date( ).
        gv_time = cl_abap_context_info=>get_system_time( ).

        "Header
        DATA(lo_generator) = cl_uuid_factory=>create_system_uuid( ).
        TRY.
            ls_entry-%cid = lo_generator->create_uuid_x16( ).
          CATCH cx_uuid_error ##NO_HANDLER.
        ENDTRY.
        DATA(ls_header_b) = lt_data_prepay[ 1 ].
        ls_entry-%param-companycode = ls_header_b-salesorg.
        ls_entry-%param-accountingdocumentheadertext = |Prepayment Posting|.
        ls_entry-%param-documentdate = lv_date.
        ls_entry-%param-postingdate = lv_date.
        ls_entry-%param-taxdeterminationdate = lv_date.
        ls_entry-%param-createdbyuser = sy-uname.
        ls_entry-%param-businesstransactiontype = lc_transactiontype.
        ls_entry-%param-documentreferenceid = lc_documentreferenceid.
        ls_entry-%param-accountingdocumenttype = lc_documenttype.
        "Items
        ls_post_data = CORRESPONDING #( ls_header_b ).
        ls_post_data-grossamount = lv_Amounttoadjust.
        lv_glacc = lt_glacc[ itemNo = '000001' category = 'B' ]-value1.
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem1) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '2107010200'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'S'
                                         iv_scenario = 'B' ).
        APPEND LINES OF ls_glitem1-%param-_glitems TO ls_entry-%param-_glitems.

        CLEAR : ls_post_data.
*          LOOP AT  lt_data_DelvSo INTO DATA(ls_delvso).
        ls_post_data = CORRESPONDING #( lt_data_DelvSo[ 1 ] ).
        ls_post_data-salesorder = lt_data_DelvSo[ 1 ]-DelvSoSalesDocument.
        ls_post_data-salesorderitem = lt_data_DelvSo[ 1 ]-DelvSoSalesDocumentItem.
        ls_post_data-wbs = lt_data_DelvSo[ 1 ]-wbs.
        ls_post_data-prepaymentrequest = lt_data_DelvSo[ 1 ]-PrepaymentReqNumPrepayment.
        ls_post_data-profitcenter = lt_data_DelvSo[ 1 ]-profitcenter.
        ls_post_data-salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg.
        ls_post_data-soldto = lt_data_DelvSo[ 1 ]-DelvSoSoldTO.
        ls_post_data-socurrency = lt_data_DelvSo[ 1 ]-DelvSoCurrency.
        ls_post_data-grossamount = lv_Amounttoadjust.
        CLEAR lv_glacc.
        lv_glacc = lt_glacc[ itemNo = '000002' category = 'B' ]-value1.
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem2) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'H'
                                         iv_scenario = 'B' ).
        APPEND LINES OF ls_glitem2-%param-_glitems TO ls_entry-%param-_glitems.
        APPEND ls_entry TO gt_entry.

        "End of Addition 28-08
      ELSEIF lv_category = 'C' AND sy-subrc = 0.

        DATA: lv_tax_rate          TYPE p LENGTH 16 DECIMALS 9,
              lv_applied_gross_amt TYPE p LENGTH 16 DECIMALS 2,
              lv_tax_code          TYPE string,
              lv_tax_amount        TYPE p LENGTH 16 DECIMALS 2.

        "Get Tax Rate from SalesOrderItem
        SELECT SINGLE
            I_SalesDocItemPricingElement~ConditionRateValue,
            I_SalesDocItemPricingElement~TaxCode
       FROM I_SalesDocItemPricingElement WHERE salesdocument = @lv_DlvOrder
                              AND salesdocumentitem = @lv_DlvOrderItem
                              AND ConditionType = 'TTX1'
                  INTO (@lv_tax_rate, @lv_tax_code).

        "Calculate Tax Amount
        lv_tax_amount = lv_Amounttoadjust * lv_tax_rate / 100.
        lv_applied_gross_amt = lv_Amounttoadjust + lv_tax_amount.

        " get the GL Accounts from CONFIG Table
        SELECT
           zr_config_value~uuid,
           zr_config_value~parameterid,
           zr_config_value~itemno,
           zr_config_value~category,
           zr_config_value~value1
         FROM
          zr_config_value
         WHERE
          parameterid = 'GLACCOUNTS_C'
          INTO TABLE @DATA(lt_glacc_c).
        "Prepare the result of Post
        lv_journal = lv_journalitem = 1.
        gv_date = cl_abap_context_info=>get_system_date( ).
        gv_time = cl_abap_context_info=>get_system_time( ).

        "Header
        DATA(lo_generator_c) = cl_uuid_factory=>create_system_uuid( ).
        TRY.
            ls_entry-%cid = lo_generator_c->create_uuid_x16( ).
          CATCH cx_uuid_error ##NO_HANDLER.
        ENDTRY.

        DATA(ls_header_c) = lt_data_prepay[ 1 ].
        ls_entry-%param-companycode = ls_header_c-salesorg.
        ls_entry-%param-accountingdocumentheadertext = |Prepayment Posting|.
        ls_entry-%param-documentdate = lv_date.
        ls_entry-%param-postingdate = lv_date.
        ls_entry-%param-taxdeterminationdate = lv_date.
        ls_entry-%param-createdbyuser = sy-uname.
        ls_entry-%param-businesstransactiontype = lc_transactiontype.
        ls_entry-%param-documentreferenceid = lc_documentreferenceid.
        ls_entry-%param-accountingdocumenttype = lc_documenttype.
        "Items

        "1st GL line -> GL
        ls_post_data = CORRESPONDING #( lt_data_DelvSo[ 1 ] ).
        ls_post_data-salesorder = lt_data_DelvSo[ 1 ]-DelvSoSalesDocument.
        ls_post_data-salesorderitem = lt_data_DelvSo[ 1 ]-DelvSoSalesDocumentItem.
        ls_post_data-wbs = lt_data_DelvSo[ 1 ]-wbs.
        ls_post_data-prepaymentrequest = lt_data_DelvSo[ 1 ]-PrepaymentReqNumPrepayment.
        ls_post_data-profitcenter = lt_data_DelvSo[ 1 ]-profitcenter.
        ls_post_data-salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg.
        ls_post_data-soldto = lt_data_DelvSo[ 1 ]-DelvSoSoldTO.
        ls_post_data-socurrency = lt_data_DelvSo[ 1 ]-DelvSoCurrency.
        ls_post_data-grossamount = lv_Amounttoadjust.
        lv_glacc = lt_glacc_c[ itemNo = '000001' category = 'C' ]-value1.

        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem1_c) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '2107010200'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'H'
                                         iv_scenario = 'C'
                                         iv_taxcode = lv_tax_code ).
        APPEND LINES OF ls_glitem1_c-%param-_glitems TO ls_entry-%param-_glitems.

        CLEAR : ls_post_data.

        "2nd GL Line -> Customer (ARItems)
        ls_post_data = CORRESPONDING #( ls_header_c ).
        ls_post_data-grossamount = lv_applied_gross_amt.
        CLEAR lv_glacc.
*        lv_glacc = lt_glacc_c[ itemNo = '000002' category = 'C' ]-value1.
        "Update to take client reconcillation account from master data: 6/5/2026
        lv_glacc = get_gl_account( iv_customer = lt_data_DelvSo[ 1 ]-DelvSoSoldTO iv_salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg ).
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem2_c) = fill_ar_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'S'
                                         iv_taxcode = lv_tax_code ).
        APPEND LINES OF ls_glitem2_c-%param-_aritems TO ls_entry-%param-_aritems.
        CLEAR : ls_post_data.

        "3rd GL Line -> GL
        ls_post_data = CORRESPONDING #( ls_header_c ).
        ls_post_data-grossamount = lv_TAX_AMOUNT.
        CLEAR lv_glacc.
        lv_glacc = lt_glacc_c[ itemNo = '000003' category = 'C' ]-value1.
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem3_c) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'H'
                                         iv_scenario = 'C'
                                         iv_taxcode = lv_tax_code ).
        APPEND LINES OF ls_glitem3_c-%param-_glitems TO ls_entry-%param-_glitems.
        CLEAR : ls_post_data.

        "4th GL Line -> Customer (ARItems)
        ls_post_data = CORRESPONDING #( ls_header_c ).
        ls_post_data-grossamount = lv_applied_gross_amt.
        CLEAR lv_glacc.
        lv_glacc = lt_glacc_c[ itemNo = '000004' category = 'C' ]-value1.
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem4_c) = fill_ar_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'S'
                                         iv_taxcode = lv_tax_code
                                         iv_specialglcode = 'A').
        APPEND LINES OF ls_glitem4_c-%param-_aritems TO ls_entry-%param-_aritems.
        CLEAR : ls_post_data.

        "5th GL Line -> Customer (ARItems)
        ls_post_data = CORRESPONDING #( ls_header_c ).
        ls_post_data-grossamount = lv_applied_gross_amt.
        CLEAR lv_glacc.
        "Update to take client reconcillation account from master data: 6/5/2026
        lv_glacc = get_gl_account( iv_customer = lt_data_DelvSo[ 1 ]-DelvSoSoldTO iv_salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg ).
*        lv_glacc = lt_glacc_c[ itemNo = '000005' category = 'C' ]-value1.
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem5_c) = fill_ar_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'H'
                                         iv_taxcode = lv_tax_code ).
        APPEND LINES OF ls_glitem5_c-%param-_aritems TO ls_entry-%param-_aritems.
        CLEAR : ls_post_data.

        APPEND ls_entry TO gt_entry.
        " Start of addition - 10/09
      ELSEIF lv_category = 'A' AND sy-subrc = 0.

        DATA: lv_taxrate          TYPE p LENGTH 16 DECIMALS 9,
              lv_applied_grossamt TYPE p LENGTH 16 DECIMALS 2,
              lv_taxcode          TYPE string,
              lv_taxamount        TYPE p LENGTH 16 DECIMALS 2,
              lv_threshold        TYPE p LENGTH 16 DECIMALS 2.

        "Get Tax Rate from SalesOrderItem
        SELECT SINGLE
            I_SalesDocItemPricingElement~ConditionRateValue,
            I_SalesDocItemPricingElement~TaxCode
       FROM I_SalesDocItemPricingElement WHERE salesdocument = @lv_DlvOrder
                              AND salesdocumentitem = @lv_DlvOrderItem
                              AND ConditionType = 'TTX1'
                  INTO (@lv_taxrate, @lv_taxcode).

        "Calculate Tax Amount
        lv_taxamount = lv_Amounttoadjust * lv_taxrate / 100.
        lv_applied_grossamt = lv_Amounttoadjust + lv_taxamount.

        " get the GL Accounts from CONFIG Table
        SELECT
           zr_config_value~uuid,
           zr_config_value~parameterid,
           zr_config_value~itemno,
           zr_config_value~category,
           zr_config_value~value1
         FROM
          zr_config_value
         WHERE
          parameterid = 'GLACCOUNTS_A'
          INTO TABLE @DATA(lt_glacc_a).
        "Prepare the result of Post
        lv_journal = lv_journalitem = 1.
        gv_date = cl_abap_context_info=>get_system_date( ).
        gv_time = cl_abap_context_info=>get_system_time( ).

        "Header
        DATA(lo_generator_a) = cl_uuid_factory=>create_system_uuid( ).
        TRY.
            ls_entry-%cid = lo_generator_a->create_uuid_x16( ).
          CATCH cx_uuid_error ##NO_HANDLER.
        ENDTRY.

        DATA(ls_header_a) = lt_data_prepay[ 1 ].
        ls_entry-%param-companycode = ls_header_a-salesorg.
        ls_entry-%param-accountingdocumentheadertext = |Prepayment Posting|.
        ls_entry-%param-documentdate = lv_date.
        ls_entry-%param-postingdate = lv_date.
        ls_entry-%param-taxdeterminationdate = lv_date.
        ls_entry-%param-createdbyuser = sy-uname.
        ls_entry-%param-businesstransactiontype = lc_transactiontype.
        ls_entry-%param-documentreferenceid = lc_documentreferenceid.
        ls_entry-%param-accountingdocumenttype = lc_documenttype.
        "Items

        IF lv_writeoff <> 'X'.
          "1st GL line -> GL
          ls_post_data = CORRESPONDING #( lt_data_DelvSo[ 1 ] ).
          ls_post_data-salesorder = lt_data_DelvSo[ 1 ]-DelvSoSalesDocument.
          ls_post_data-salesorderitem = lt_data_DelvSo[ 1 ]-DelvSoSalesDocumentItem.
          ls_post_data-wbs = lt_data_DelvSo[ 1 ]-wbs.
          ls_post_data-prepaymentrequest = lt_data_DelvSo[ 1 ]-PrepaymentReqNumPrepayment.
          ls_post_data-profitcenter = lt_data_DelvSo[ 1 ]-profitcenter.
          ls_post_data-salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg.
          ls_post_data-soldto = lt_data_DelvSo[ 1 ]-DelvSoSoldTO.
*                Get GL acc from Customer Master
          SELECT SINGLE ReconciliationAccount
          FROM I_CustomerCompany
          WHERE CompanyCode = @ls_header_a-salesorg
          AND Customer = @ls_post_data-soldto
          INTO @DATA(lv_reconacc).
          ls_post_data-socurrency = lt_data_DelvSo[ 1 ]-DelvSoCurrency.
          ls_post_data-grossamount = lv_Amounttoadjust.
          lv_glacc = lt_glacc_a[ itemNo = '000001' category = 'A' ]-value1.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem1_a) = fill_gl_item( is_data = ls_post_data
                                           iv_itemno = lv_itemno
                                           "iv_glacc = '2107010200'
                                           iv_glacc = lv_glacc
                                           iv_debitcredit = 'H'
                                           iv_scenario = 'A'
                                           iv_taxcode = lv_taxcode ).
          APPEND LINES OF ls_glitem1_a-%param-_glitems TO ls_entry-%param-_glitems.

          CLEAR : ls_post_data.

          "2nd GL Line -> Customer (ARItems)
          ls_post_data = CORRESPONDING #( ls_header_a ).
          ls_post_data-grossamount = lv_applied_grossamt.
          CLEAR lv_glacc.
          "lv_glacc = lt_glacc_a[ itemNo = '000002' category = 'A' ]-value1.
          lv_glacc = lv_reconacc.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem2_a) = fill_ar_item( is_data = ls_post_data
                                           iv_itemno = lv_itemno
                                           "iv_glacc = '1107200100'
                                           iv_glacc = lv_glacc
                                           iv_debitcredit = 'S'
                                           iv_taxcode = lv_taxcode ).
          APPEND LINES OF ls_glitem2_a-%param-_aritems TO ls_entry-%param-_aritems.
          CLEAR : ls_post_data.

          "3rd GL Line -> GL
          ls_post_data = CORRESPONDING #( ls_header_a ).
          ls_post_data-grossamount = lv_TAXAMOUNT.
          CLEAR lv_glacc.
          lv_glacc = lt_glacc_a[ itemNo = '000003' category = 'A' ]-value1.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem3_a) = fill_gl_item( is_data = ls_post_data
                                           iv_itemno = lv_itemno
                                           "iv_glacc = '1107200100'
                                           iv_glacc = lv_glacc
                                           iv_debitcredit = 'H'
                                           iv_scenario = 'A'
                                           iv_taxcode = lv_taxcode ).
          APPEND LINES OF ls_glitem3_a-%param-_glitems TO ls_entry-%param-_glitems.
          CLEAR : ls_post_data.

          "4rd GL Line -> GL
          ls_post_data = CORRESPONDING #( ls_header_a ).
          ls_post_data-grossamount = lv_TAXAMOUNT.
          CLEAR lv_glacc.
          lv_glacc = lt_glacc_a[ itemNo = '000004' category = 'A' ]-value1.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem4_a) = fill_gl_item( is_data = ls_post_data
                                           iv_itemno = lv_itemno
                                           "iv_glacc = '1107200100'
                                           iv_glacc = lv_glacc
                                           iv_debitcredit = 'H'
                                           iv_scenario = 'A'
                                           iv_taxcode = lv_taxcode ).
          APPEND LINES OF ls_glitem4_a-%param-_glitems TO ls_entry-%param-_glitems.
          CLEAR : ls_post_data.

          "5th GL Line -> Customer (ARItems)
          ls_post_data = CORRESPONDING #( ls_header_a ).
          ls_post_data-grossamount = lv_applied_grossamt.
          CLEAR lv_glacc.
          lv_glacc = lt_glacc_a[ itemNo = '000005' category = 'A' ]-value1.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem5_a) = fill_ar_item( is_data = ls_post_data
                                           iv_itemno = lv_itemno
                                           "iv_glacc = '1107200100'
                                           iv_glacc = lv_glacc
                                           iv_debitcredit = 'S'
                                           iv_taxcode = lv_taxcode
                                           iv_specialglcode = 'A').
          APPEND LINES OF ls_glitem5_a-%param-_aritems TO ls_entry-%param-_aritems.
          CLEAR : ls_post_data.

          "6th GL Line -> Customer (ARItems)
          ls_post_data = CORRESPONDING #( ls_header_a ).
          ls_post_data-grossamount = lv_applied_grossamt.
          CLEAR lv_glacc.
          "lv_glacc = lt_glacc_a[ itemNo = '000006' category = 'A' ]-value1.
          lv_glacc = lv_reconacc.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem6_a) = fill_ar_item( is_data = ls_post_data
                                           iv_itemno = lv_itemno
                                           "iv_glacc = '1107200100'
                                           iv_glacc = lv_glacc
                                           iv_debitcredit = 'H'
                                           iv_taxcode = lv_taxcode ).
          APPEND LINES OF ls_glitem6_a-%param-_aritems TO ls_entry-%param-_aritems.
          CLEAR : ls_post_data.

          "7th GL Line -> Customer (ARItems)
          ls_post_data = CORRESPONDING #( ls_header_a ).
          ls_post_data-grossamount = lv_TAXAMOUNT.
          CLEAR lv_glacc.
          lv_glacc = lt_glacc_a[ itemNo = '000007' category = 'A' ]-value1.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem7_a) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'S'
                                         iv_scenario = 'A'
                                         iv_taxcode = lv_taxcode ).
          APPEND LINES OF ls_glitem7_a-%param-_glitems TO ls_entry-%param-_glitems.
*                DATA(ls_glitem7_a) = fill_ar_item( is_data = ls_post_data
*                                                 iv_itemno = lv_itemno
*                                                 "iv_glacc = '1107200100'
*                                                 iv_glacc = lv_glacc
*                                                 iv_debitcredit = 'S'
*                                                 iv_taxcode = lv_taxcode ).
*                APPEND LINES OF ls_glitem7_a-%param-_aritems TO ls_entry-%param-_aritems.
          CLEAR : ls_post_data.

        ELSE.
          "Begin Rounding threshold posting
          DATA(lv_PrepaymentRemainingAmount) = VALUE #( lt_data_prepay[ 1 ]-PrepaymentRemainingAmount OPTIONAL ).
          DATA(lv_DelvRemainingAmount) = VALUE #( lt_data_prepay[ 1 ]-DelvRemainingAmount OPTIONAL ).

          DATA lv_diff_amt TYPE p DECIMALS 2.

          lv_diff_amt = abs( lv_DelvRemainingAmount - lv_PrepaymentRemainingAmount ).
*            IF  lv_DelvRemainingAmount > lv_PrepaymentRemainingAmount.
*              lv_threshold = VALUE #( lt_rounding[ value1 = lv_salesorg ]-value2 OPTIONAL ).
*              IF ( lv_DelvRemainingAmount - lv_PrepaymentRemainingAmount ) < lv_threshold.
          "8th GL Line -> Customer (ARItems)
*                ls_post_data = CORRESPONDING #( ls_header_a ).
          ls_post_data = CORRESPONDING #( lt_data_DelvSo[ 1 ] ).
          ls_post_data-salesorder = lt_data_DelvSo[ 1 ]-DelvSoSalesDocument.
          ls_post_data-salesorderitem = lt_data_DelvSo[ 1 ]-DelvSoSalesDocumentItem.
          ls_post_data-wbs = lt_data_DelvSo[ 1 ]-wbs.
          ls_post_data-prepaymentrequest = lt_data_DelvSo[ 1 ]-PrepaymentReqNumPrepayment.
          ls_post_data-profitcenter = lt_data_DelvSo[ 1 ]-profitcenter.
          ls_post_data-salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg.
          ls_post_data-soldto = lt_data_DelvSo[ 1 ]-DelvSoSoldTO.
          ls_post_data-socurrency = lt_data_DelvSo[ 1 ]-DelvSoCurrency.
          ls_post_data-grossamount = lv_diff_amt.
          CLEAR lv_glacc.

          lv_glacc = lt_glaccrndg[ itemNo = '000001'  ]-value1.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem8_a) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'H'
                                         iv_scenario = 'A'
                                         iv_taxcode = '').
          APPEND LINES OF ls_glitem8_a-%param-_glitems TO ls_entry-%param-_glitems.
          CLEAR : ls_post_data.

          "9th GL Line -> Customer (ARItems)
*                ls_post_data = CORRESPONDING #( ls_header_a ).
          ls_post_data = CORRESPONDING #( lt_data_DelvSo[ 1 ] ).
          ls_post_data-salesorder = lt_data_DelvSo[ 1 ]-DelvSoSalesDocument.
          ls_post_data-salesorderitem = lt_data_DelvSo[ 1 ]-DelvSoSalesDocumentItem.
          ls_post_data-wbs = lt_data_DelvSo[ 1 ]-wbs.
          ls_post_data-prepaymentrequest = lt_data_DelvSo[ 1 ]-PrepaymentReqNumPrepayment.
          ls_post_data-profitcenter = lt_data_DelvSo[ 1 ]-profitcenter.
          ls_post_data-salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg.
          ls_post_data-soldto = lt_data_DelvSo[ 1 ]-DelvSoSoldTO.
          ls_post_data-socurrency = lt_data_DelvSo[ 1 ]-DelvSoCurrency.
          ls_post_data-grossamount = lv_diff_amt.
          CLEAR lv_glacc.

          lv_glacc = lt_glaccrndg[ itemNo = '000002'  ]-value1.
          lv_itemno = lv_itemno + 1.
          DATA(ls_glitem9_a) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'S'
                                         iv_scenario = 'A'
                                         iv_taxcode = '' ).
          APPEND LINES OF ls_glitem9_a-%param-_glitems TO ls_entry-%param-_glitems.
          CLEAR : ls_post_data.
*              ENDIF.
*            ENDIF.
*    End Rounding threshold posting
        ENDIF.



        APPEND ls_entry TO gt_entry.

        " End of addititon - 10/09

        "Start of addition - Scenario D
      ELSEIF lv_category = 'D1' AND sy-subrc = 0.

        DATA: lv_tax_rate_D          TYPE p LENGTH 16 DECIMALS 9,
              lv_applied_gross_amt_D TYPE p LENGTH 16 DECIMALS 2,
              lv_tax_code_D          TYPE string,
              lv_tax_amount_D        TYPE p LENGTH 16 DECIMALS 2.

        "Get Tax Rate from SalesOrderItem
        SELECT SINGLE
            I_SalesDocItemPricingElement~ConditionRateValue,
            I_SalesDocItemPricingElement~TaxCode
       FROM I_SalesDocItemPricingElement WHERE salesdocument = @lv_DlvOrder
                              AND salesdocumentitem = @lv_DlvOrderItem
                              AND ConditionType = 'TTX1'
                  INTO (@lv_tax_rate, @lv_tax_code).


        "Calculate Tax Amount
        lv_tax_amount = lv_Amounttoadjust * lv_tax_rate / 100.
        lv_applied_gross_amt = lv_Amounttoadjust + lv_tax_amount.

        " get the GL Accounts from CONFIG Table
        SELECT
           zr_config_value~uuid,
           zr_config_value~parameterid,
           zr_config_value~itemno,
           zr_config_value~category,
           zr_config_value~value1
         FROM
          zr_config_value
         WHERE
          parameterid = 'GLACCOUNTS_D'
          INTO TABLE @DATA(lt_glacc_d).
        "Prepare the result of Post
        lv_journal = lv_journalitem = 1.
        gv_date = cl_abap_context_info=>get_system_date( ).
        gv_time = cl_abap_context_info=>get_system_time( ).

        "Header
        DATA(lo_generator_d) = cl_uuid_factory=>create_system_uuid( ).
        TRY.
            ls_entry-%cid = lo_generator_d->create_uuid_x16( ).
          CATCH cx_uuid_error ##NO_HANDLER.
        ENDTRY.

        DATA(ls_header_d) = lt_data_prepay[ 1 ].
        ls_entry-%param-companycode = ls_header_d-salesorg.
        ls_entry-%param-accountingdocumentheadertext = |Prepayment Posting|.
        ls_entry-%param-documentdate = lv_date.
        ls_entry-%param-postingdate = lv_date.
        ls_entry-%param-taxdeterminationdate = lv_date.
        ls_entry-%param-createdbyuser = sy-uname.
        ls_entry-%param-businesstransactiontype = lc_transactiontype.
        ls_entry-%param-documentreferenceid = lc_documentreferenceid.
        ls_entry-%param-accountingdocumenttype = lc_documenttype.
        "Items

        "1st GL line -> GL
        ls_post_data = CORRESPONDING #( lt_data_DelvSo[ 1 ] ).
        ls_post_data-salesorder = lt_data_DelvSo[ 1 ]-DelvSoSalesDocument.
        ls_post_data-salesorderitem = lt_data_DelvSo[ 1 ]-DelvSoSalesDocumentItem.
        ls_post_data-wbs = lt_data_DelvSo[ 1 ]-wbs.
        ls_post_data-prepaymentrequest = lt_data_DelvSo[ 1 ]-PrepaymentReqNumPrepayment.
        ls_post_data-profitcenter = lt_data_DelvSo[ 1 ]-profitcenter.
        ls_post_data-salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg.
        ls_post_data-soldto = lt_data_DelvSo[ 1 ]-DelvSoSoldTO.
        ls_post_data-socurrency = lt_data_DelvSo[ 1 ]-DelvSoCurrency.
        ls_post_data-grossamount = lv_Amounttoadjust.
        lv_glacc = lt_glacc_d[ itemNo = '000001' category = 'D' ]-value1.

        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem1_d) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '2107010200'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'H'
                                         iv_scenario = 'D1'
                                         iv_taxcode = lv_tax_code ).
        APPEND LINES OF ls_glitem1_d-%param-_glitems TO ls_entry-%param-_glitems.

        CLEAR : ls_post_data.

        "2nd GL Line -> Customer (ARItems)
        ls_post_data = CORRESPONDING #( ls_header_d ).
        ls_post_data-grossamount = lv_applied_gross_amt.
        CLEAR lv_glacc.
*            lv_glacc = lt_glacc_c[ itemNo = '000002' category = 'C' ]-value1.
        "Update to take client reconcillation account from master data: 6/5/2026
        lv_glacc = get_gl_account( iv_customer = lt_data_DelvSo[ 1 ]-DelvSoSoldTO iv_salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg ).
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem2_d) = fill_ar_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'S'
                                         iv_taxcode = lv_tax_code ).
        APPEND LINES OF ls_glitem2_d-%param-_aritems TO ls_entry-%param-_aritems.
        CLEAR : ls_post_data.

        "3rd GL Line -> GL
        ls_post_data = CORRESPONDING #( ls_header_d ).
        ls_post_data-grossamount = lv_TAX_AMOUNT.
        CLEAR lv_glacc.
        lv_glacc = lt_glacc_d[ itemNo = '000003' category = 'D' ]-value1.
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem3_d) = fill_gl_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'H'
                                         iv_scenario = 'D1'
                                         iv_taxcode = lv_tax_code ).
        APPEND LINES OF ls_glitem3_d-%param-_glitems TO ls_entry-%param-_glitems.
        CLEAR : ls_post_data.

        "4th GL Line -> Customer (ARItems)
        ls_post_data = CORRESPONDING #( ls_header_d ).
        ls_post_data-grossamount = lv_applied_gross_amt.
        CLEAR lv_glacc.
        lv_glacc = lt_glacc_d[ itemNo = '000004' category = 'D' ]-value1.
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem4_d) = fill_ar_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'S'
                                         iv_taxcode = lv_tax_code
                                         iv_specialglcode = 'A').
        APPEND LINES OF ls_glitem4_d-%param-_aritems TO ls_entry-%param-_aritems.
        CLEAR : ls_post_data.

        "5th GL Line -> Customer (ARItems)
        ls_post_data = CORRESPONDING #( ls_header_d ).
        ls_post_data-grossamount = lv_applied_gross_amt.
        CLEAR lv_glacc.
        "Update to take client reconcillation account from master data: 6/5/2026
        lv_glacc = get_gl_account( iv_customer = lt_data_DelvSo[ 1 ]-DelvSoSoldTO iv_salesorg = lt_data_DelvSo[ 1 ]-DelvSoSalesOrg ).
*            lv_glacc = lt_glacc_c[ itemNo = '000005' category = 'C' ]-value1.
        lv_itemno = lv_itemno + 1.
        DATA(ls_glitem5_d) = fill_ar_item( is_data = ls_post_data
                                         iv_itemno = lv_itemno
                                         "iv_glacc = '1107200100'
                                         iv_glacc = lv_glacc
                                         iv_debitcredit = 'H'
                                         iv_taxcode = lv_tax_code ).
        APPEND LINES OF ls_glitem5_d-%param-_aritems TO ls_entry-%param-_aritems.
        CLEAR : ls_post_data.

        APPEND ls_entry TO gt_entry.
      ENDIF.

    ENDIF.


* post Journal entries
    IF gt_entry IS NOT INITIAL.

      MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
        ENTITY journalentry
        EXECUTE post FROM gt_entry
        MAPPED FINAL(ls_post_mapped)
        FAILED FINAL(ls_post_failed)
        REPORTED FINAL(ls_post_reported).

      " ── Guard 1: MODIFY itself reported failures → do NOT commit ─────────
      IF ls_post_failed IS NOT INITIAL.
        CLEAR lv_all_messages.
        LOOP AT ls_post_reported-journalentry INTO DATA(ls_report) FROM 2.
          IF ls_report-%msg IS BOUND.
            lo_msg = ls_report-%msg.
            DATA(lv_txt_modify) = lo_msg->if_message~get_longtext( ).
            lv_all_messages = COND #(
              WHEN lv_all_messages IS INITIAL THEN lv_txt_modify
              ELSE lv_all_messages && '||' && lv_txt_modify ).
          ENDIF.
        ENDLOOP.

        APPEND VALUE #(
          Status  = 'ERROR'
          Message = COND #( WHEN lv_all_messages IS NOT INITIAL
                            THEN lv_all_messages
                            ELSE 'Journal entry validation failed before commit' )
        ) TO rt_result.
        RETURN.
      ENDIF.

      " ── Commit ──────────────────────────────────────────────────────────
      COMMIT ENTITIES BEGIN
        RESPONSE OF i_journalentrytp
        FAILED DATA(lt_commit_failed)
        REPORTED DATA(lt_commit_reported).
      COMMIT ENTITIES END.

      " ── Guard 2: commit failed → surface the real message ────────────────
      IF lt_commit_failed IS NOT INITIAL.
        CLEAR lv_all_messages.
        LOOP AT lt_commit_reported-journalentry INTO DATA(ls_je_err).
          IF ls_je_err-%msg IS BOUND.                 " was: ls_report-%msg (stale)
            lo_msg = ls_je_err-%msg.
            DATA(lv_txt_commit) = lo_msg->if_message~get_longtext( ).
            lv_all_messages = COND #(
              WHEN lv_all_messages IS INITIAL THEN lv_txt_commit
              ELSE lv_all_messages && '||' && lv_txt_commit ).
          ENDIF.
        ENDLOOP.

        APPEND VALUE #(
          Status  = 'ERROR'
          Message = COND #( WHEN lv_all_messages IS NOT INITIAL
                            THEN lv_all_messages
                            ELSE 'Commit failed without detailed message' )
        ) TO rt_result.
        RETURN.
      ENDIF.

      " ── Success: read the created document from MAPPED, not REPORTED ──────
      LOOP AT lt_commit_reported-journalentry INTO DATA(ls_je).
        IF ls_je-AccountingDocument IS NOT INITIAL.
          APPEND VALUE #(
            AccountingDocument = ls_je-AccountingDocument
            Status             = 'SUCCESS'
            Message            = ''
          ) TO rt_result.
        ELSE.
          APPEND VALUE #(
            Status  = 'ERROR'
            Message = 'Commit reported no accounting document number'
          ) TO rt_result.
        ENDIF.
      ENDLOOP.

      " ── Safety net: MAPPED empty but no failure flagged ──────────────────
      IF rt_result IS INITIAL.
        APPEND VALUE #(
          Status  = 'ERROR'
          Message = 'No accounting document produced by posting'
        ) TO rt_result.
      ENDIF.

    ENDIF.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    DATA lt_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.


    DATA(lt_result) = PrepayPost( it_filters = lt_ranges ).
    IF gt_return IS NOT INITIAL.
      out->write( gt_return ).
    ELSE.
      out->write( lt_result ).
    ENDIF.

  ENDMETHOD.


  METHOD get_gl_account.
    SELECT SINGLE
      ReconciliationAccount
    FROM I_CustomerCompany
    WHERE CompanyCode = @iv_salesorg
    AND Customer = @iv_customer
    INTO @rv_glacc.
  ENDMETHOD.


      METHOD if_rap_query_provider~select.

        DATA: gt_result TYPE STANDARD TABLE OF zi_prepaypost_custom_ent.

        DATA(top)     = io_request->get_paging( )->get_page_size( ).
        DATA(skip)    = io_request->get_paging( )->get_offset( ).
        DATA(requested_fields)  = io_request->get_requested_elements( ).
        DATA(sort_order)    = io_request->get_sort_elements( ).

        TRY.

            DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).

            gt_posted = PrepayPost( it_filters = lt_ranges ).
            IF gt_posted IS NOT INITIAL.
              LOOP AT gt_posted INTO DATA(ls_posted).

                APPEND VALUE #(
                  AccountingDocument = ls_posted-AccountingDocument
                  Status             = ls_posted-Status
                  Remarks            = ls_posted-Message
                ) TO gt_result.

              ENDLOOP.

            ELSE.
              APPEND VALUE #(
                Status  = 'ERROR'
                Remarks = 'No journal entry data was prepared for posting'
              ) TO gt_result.

            ENDIF.

          CATCH cx_root INTO DATA(exception).

            " Guard against NULL: get_latest_t100_exception returns an initial
            " reference when the caught exception is not T100-message-enabled
            " (e.g. CX_SY_ITAB_LINE_NOT_FOUND). Dereferencing that NULL is what
            " caused the previous short dump (CX_SY_REF_IS_INITIAL).
            DATA(lo_t100_exception) = cl_message_helper=>get_latest_t100_exception( exception ).

            DATA(lv_exception_message) = COND string(
              WHEN lo_t100_exception IS BOUND
              THEN lo_t100_exception->if_message~get_longtext( )
              ELSE exception->get_text( ) ).

            CLEAR gt_result.
            APPEND VALUE #(
              Status  = 'ERROR'
              Remarks = lv_exception_message
            ) TO gt_result.

        ENDTRY.

        " Moved OUTSIDE the TRY so it always runs — success path AND catch path.
        " Previously this was only inside the TRY, so any exception meant
        " io_response->set_data() was never called at all.
        io_response->set_data( gt_result ).

        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( gt_result ) ).
        ENDIF.

    ENDMETHOD.
ENDCLASS.
