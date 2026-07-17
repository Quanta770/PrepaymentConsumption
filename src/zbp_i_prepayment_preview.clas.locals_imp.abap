
CLASS lcx_json_error DEFINITION INHERITING FROM cx_static_check CREATE PUBLIC.
ENDCLASS.
CLASS lcx_json_error IMPLEMENTATION. ENDCLASS.

CLASS lhc_PrepaymentPreview DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.
    DATA: gt_entry TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          lt_entry LIKE LINE OF gt_entry.
    TYPES: ty_je_create_line TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
           ty_glitem         TYPE LINE OF ty_je_create_line.

    TYPES: BEGIN OF ty_poc_param,
             Parameter1 TYPE string,
             Parameter2 TYPE int4,
           END OF ty_poc_param.
    TYPES tty_poc_params TYPE STANDARD TABLE OF ty_poc_param WITH EMPTY KEY.

    TYPES: BEGIN OF ty_gl_account,
         glacc_number TYPE akont,
         glacc_name   TYPE i_glaccounttext-GLAccountName,
       END OF ty_gl_account.

  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR PrepaymentPreview RESULT result.
    METHODS processJsonFile FOR MODIFY
      IMPORTING keys FOR ACTION PrepaymentPreview~processJsonFile .
    METHODS get_gl_account
      IMPORTING iv_customer   TYPE zi_prepayment_delivery_so-DelvSoSoldTO
                iv_salesorg   TYPE zi_prepayment_delivery_so-DelvSoSalesOrg
      RETURNING VALUE(rs_glacc) TYPE ty_gl_account.
    METHODS PrepayPreview FOR MODIFY
      IMPORTING keys FOR ACTION PrepaymentPreview~PrepayPreview RESULT result.
*    METHODS PrepayPost FOR MODIFY
*      IMPORTING keys FOR ACTION PrepaymentPreview~PrepayPost RESULT result.
    METHODS convert_to_correct_amount
      IMPORTING iv_amount        TYPE zi_prepayment_delivery_so-DelvSoAmount
                iv_currency      TYPE waers
      RETURNING VALUE(rv_result) TYPE zi_prepayment_delivery_so-DelvSoAmount.
    METHODS fill_gl_item
      IMPORTING
        is_data        TYPE zstprepayglitem   " Structure of ls_data-item
        iv_itemno      TYPE posnr
        iv_glacc       TYPE saknr
        iv_debitcredit TYPE shkzg
      RETURNING
        VALUE(rs_item) TYPE ty_glitem. " One GL item structure
    METHODS parse_json_text
      IMPORTING i_json    TYPE string
      EXPORTING et_params TYPE tty_poc_params
      RAISING   lcx_json_error.


ENDCLASS.


CLASS lhc_PrepaymentPreview IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.
  METHOD convert_to_correct_amount.

    SELECT SINGLE FROM i_currency WITH PRIVILEGED ACCESS
        FIELDS decimals
        WHERE currency = @iv_currency
        INTO @DATA(lv_decimal).

    rv_result = SWITCH #( lv_decimal WHEN 0 THEN iv_amount / 100 ELSE iv_amount ).

  ENDMETHOD.
  METHOD processJsonFile.
    DATA lt_params TYPE tty_poc_params.
    TRY.
        parse_json_text(
          EXPORTING i_json    = keys[ 1 ]-%param-FileContent
          IMPORTING et_params = lt_params ).
      CATCH lcx_json_error INTO DATA(lx).
        APPEND VALUE #( %msg = new_message_with_text(
                           severity = if_abap_behv_message=>severity-error
                           text     = |Invalid JSON: { lx->get_text( ) }| ) )
               TO reported-PrepaymentPreview.
        RETURN.
    ENDTRY.

    "DATA lt_create TYPE TABLE FOR CREATE zr_poc_action_log.
    DATA idx TYPE i.
    LOOP AT lt_params INTO DATA(ls_p).
      idx += 1.
*      data(lt_create) = VALUE #(
*        %cid            = |C{ idx }|
*        Param1          = ls_p-Parameter1
*        Param2          = ls_p-Parameter2
*        %control-Param1 = if_abap_behv=>mk-on
*        %control-Param2 = if_abap_behv=>mk-on ) .
    ENDLOOP.


  ENDMETHOD.
  METHOD parse_json_text.
    DATA(lv_json) = i_json.

    " If a data-URL was pasted, keep only the part after 'base64,'
    DATA(lv_b64) = VALUE string( ).
    IF lv_json CS 'base64,'.
      SPLIT lv_json AT 'base64,' INTO DATA(dummy) lv_b64.
    ENDIF.

    DATA(name_map) = VALUE /ui2/cl_json=>name_mappings(
                        ( abap = 'PARAMETER1' json = 'Parameter1' )
                        ( abap = 'PARAMETER2' json = 'Parameter2' ) ).

    TRY.
        IF lv_b64 IS INITIAL.
          /ui2/cl_json=>deserialize(
            EXPORTING json          = lv_json
                      name_mappings = name_map
            CHANGING  data          = et_params ).
        ELSE.
          DATA lx TYPE xstring.
          cl_web_http_utility=>decode_x_base64(
            EXPORTING encoded = lv_b64
            RECEIVING decoded = lx ).
          /ui2/cl_json=>deserialize(
            EXPORTING jsonx         = lx
                      name_mappings = name_map
            CHANGING  data          = et_params ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_any).
        " Fallback: single object -> one row
        DATA ls_one TYPE ty_poc_param.
        TRY.
            IF lv_b64 IS INITIAL.
              /ui2/cl_json=>deserialize(
                EXPORTING json          = lv_json
                          name_mappings = name_map
                CHANGING  data          = ls_one ).
            ELSE.
              /ui2/cl_json=>deserialize(
                EXPORTING jsonx         = lx
                          name_mappings = name_map
                CHANGING  data          = ls_one ).
            ENDIF.
          CATCH cx_root.
            RAISE EXCEPTION TYPE lcx_json_error EXPORTING previous = lx_any.
        ENDTRY.
        IF ls_one IS NOT INITIAL.
          et_params = VALUE tty_poc_params( ( ls_one ) ).
        ELSE.
          RAISE EXCEPTION TYPE lcx_json_error EXPORTING previous = lx_any.
        ENDIF.
    ENDTRY.

    IF et_params IS INITIAL.
      RAISE EXCEPTION TYPE lcx_json_error.
    ENDIF.
  ENDMETHOD.
  METHOD PrepayPreview.

    DATA(lv_keys) = keys[ 1 ]-%param.
    DATA(lv_PreOrder) = lv_keys-prepaymentso.
    DATA(lv_PreOrderItem) = lv_keys-prepaymentsoitem.
    DATA(lv_DlvOrder) = lv_keys-deliveryso.
    DATA(lv_DlvOrderItem) = lv_keys-deliverysoitem.
    DATA(lv_category) = lv_keys-scenario.
    DATA(lv_Amounttoadjust) = lv_keys-amounttoapply.
    DATA(lv_prepaycurr) = lv_keys-prepaycurrency .
    DATA(lv_delvcurr) = lv_keys-delvcurrency .
*    DATA: lt_data_prv TYPE table for read RESULT ZC_PREPAYMENT_PREVIEW ,
*          ls_data_prv type zi_preview_result.
    DATA: lt_data_tmp TYPE STANDARD TABLE OF zc_prepayment_delivery_so,
          lt_result   TYPE TABLE FOR READ RESULT zc_prepayment_preview,
          ls_data_prv LIKE LINE OF lt_result.

    DATA: lv_journal     TYPE i,
          lv_journalitem TYPE i.
    "Select Data for the parameters passed
    SELECT
    zc_prepayment_delivery_so~prepaymentreqnumprepayment,
    zc_prepayment_delivery_so~prepaymentso,
    zc_prepayment_delivery_so~prepaymentsoitem,
    zc_prepayment_delivery_so~prepaymentscenariopy,
    zc_prepayment_delivery_so~prepaymentcurrency,
    zc_prepayment_delivery_so~prepaymentgrossamount,
    zc_prepayment_delivery_so~delvsosalesdocument,
    zc_prepayment_delivery_so~delvsosalesdocumentitem,
    zc_prepayment_delivery_so~delvsocurrency,
    zc_prepayment_delivery_so~delvsoamount,
    zc_prepayment_delivery_so~DelvSoSalesOrg,
    zc_prepayment_delivery_so~delvsosoldto,
    zc_prepayment_delivery_so~PrepaymentRemainingAmount,
    zc_prepayment_delivery_so~DelvRemainingAmount
  FROM
   zc_prepayment_delivery_so
  WHERE prepaymentreqnumprepayment = @lv_keys-prepaymentrequestp
  INTO TABLE @DATA(lt_data_tmp1).
    " get the GL Accounts from CONFIG Table
    DATA(lvs_Category) = COND #( WHEN lv_category = 'B'
                           THEN 'GLACCOUNTS_B'
                           WHEN lv_category = 'C'
                           THEN 'GLACCOUNTS_C'
                           WHEN lv_category = 'A'
                           THEN 'GLACCOUNTS_A'
                           WHEN lv_category = 'D1' OR lv_category = 'D2'
                           THEN 'GLACCOUNTS_D').
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
      parameterid = @lvs_Category
      INTO TABLE @DATA(lt_glacc).
* Read Delivery SO Net amount and tax Amount
    SELECT
         i_salesdocumentitem~salesdocument,
         i_salesdocumentitem~salesdocumentitem,
         i_salesdocumentitem~netamount,
         i_salesdocumentitem~netpriceamount,
         i_salesdocumentitem~taxamount,
         i_salesdocumentitem~YY1_StatWBSExt_SDI AS wbs
    FROM i_salesdocumentitem WHERE salesdocument = @lv_DlvOrder
                           AND salesdocumentitem = @lv_DlvOrderItem
               INTO TABLE @DATA(lt_delvSo)        .
    SELECT
       i_salesdocumentitem~salesdocument,
       i_salesdocumentitem~salesdocumentitem,
       i_salesdocumentitem~netamount,
       i_salesdocumentitem~netpriceamount,
       i_salesdocumentitem~taxamount,
       i_salesdocumentitem~YY1_StatWBSExt_SDI AS wbs
  FROM i_salesdocumentitem WHERE salesdocument = @lv_PreOrder
                         AND salesdocumentitem = @lv_PreOrderItem
             INTO TABLE @DATA(lt_PrepaySo)        .
    "Prepare the result of Preview.
    lv_journal = lv_journalitem = 1.
    " LOOP AT lt_data_tmp1 ASSIGNING FIELD-SYMBOL(<fs_data_tmp>).
* Rounding Threshold from Config table
    DATA(lv_salesOrg) = VALUE #( lt_data_tmp1[ 1 ]-DelvSoSalesOrg  OPTIONAL ).
    DATA(lv_soldto) = VALUE #( lt_data_tmp1[ 1 ]-delvsosoldto OPTIONAL ).
    "Updated 6/5/2026 get GL reconcillation account from customer master data
    DATA(ls_gl_acc_data) = get_gl_account(
                            iv_customer = lv_soldto
                            iv_salesorg = lv_salesOrg ).
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
    "IF sy-tabix = 1.
    IF lv_category = 'B'.
      ls_data_prv     = VALUE #(
                             journalentry = lv_journal
                             journalitem = lv_journalitem
                             "salesorder =  <fs_data_tmp>-PrepaymentSO
                              salesorder = lv_PreOrder
*                               glaccount = COND #( WHEN <fs_data_tmp>-PrepaymentScenarioPY = 'B'
*                                                   THEN '2107010200' )
                             "glaccount = '2107010200'
                             glaccount = lt_glacc[ value3 = 'D' category = lv_category ]-value1
                             accountname = 'Deferred Revenue'
                             debit =   lv_Amounttoadjust                           "<fs_data_tmp>-PrepaymentGrossAmount
                             credit = 0
                             currencycd = lv_prepaycurr                      "<fs_data_tmp>-PrepaymentCurrency
                             wbselement = lt_prepaySo[ 1 ]-wbs  ).
      APPEND ls_data_prv TO lt_result.
      APPEND VALUE #( %cid_ref = keys[ 1 ]-%cid_ref
                     journalentry = '1000000001'
                     journalitem = '00001'
                     %param = CORRESPONDING #( ls_data_prv ) ) TO result.
      lv_journalitem += 1.
      ls_data_prv     = VALUE #(
                              journalentry = lv_journal
                              journalitem = lv_journalitem
                              salesorder =  lv_keys-deliveryso      "<fs_data_tmp>-delvsosalesdocument
                              "glaccount = '1107200100'
                              glaccount = lt_glacc[ value3 = 'C' category = lv_category ]-value1
                              accountname = 'Accrued Revenue'
                              debit =  0
                              credit =   lv_Amounttoadjust                           "<fs_data_tmp>-delvsoamount
                              currencycd =   lv_prepaycurr                            "<fs_data_tmp>-delvsocurrency
                              wbselement = lt_delvSo[ 1 ]-wbs ).
      APPEND VALUE #( %cid_ref = keys[ 1 ]-%cid_ref
                     journalentry = '1000000001'
                     journalitem = '00001'
                     %param = CORRESPONDING #( ls_data_prv ) ) TO result.
      lv_journalitem += 1.
    ENDIF.
    IF lv_category = 'C'.
      SORT lt_glacc BY ItemNo.


      DATA: lv_tax_rate          TYPE p LENGTH 16 DECIMALS 9,
            lv_applied_gross_amt TYPE p LENGTH 16 DECIMALS 2,
            lv_tax_amount        TYPE p LENGTH 16 DECIMALS 2.

      "Get Tax Rate from SalesOrderItem
      SELECT SINGLE
          I_SalesDocItemPricingElement~ConditionRateValue
     FROM I_SalesDocItemPricingElement WHERE salesdocument = @lv_DlvOrder
                            AND salesdocumentitem = @lv_DlvOrderItem
                            AND ConditionType = 'TTX1'
                INTO @lv_tax_rate.

      "Calculate Tax Amount
      lv_tax_amount = lv_Amounttoadjust * lv_tax_rate / 100.
      lv_applied_gross_amt = lv_Amounttoadjust + lv_tax_amount.

      LOOP AT lt_glacc ASSIGNING FIELD-SYMBOL(<lfs_glacc>).

        ls_data_prv     = VALUE #(
                              journalentry = lv_journal
                              journalitem = lv_journalitem
                              salesorder = COND #( WHEN <lfs_glacc>-ItemNo = '1'
                                                THEN lv_keys-deliveryso
                                                WHEN  <lfs_glacc>-ItemNo = '2' OR <lfs_glacc>-ItemNo = '3' OR <lfs_glacc>-ItemNo = '4' OR <lfs_glacc>-ItemNo = '5'
                                                THEN  lv_PreOrder   )
*                              glaccount = <lfs_glacc>-value1
                                "Updated 6/5/2026
                              glaccount = COND #( WHEN <lfs_glacc>-ItemNo = '2' or <lfs_glacc>-ItemNo = '5'
                                                THEN ls_gl_acc_data-glacc_number
                                                ELSE  <lfs_glacc>-value1 )
*                              accountname = <lfs_glacc>-value2
                                "Updated 6/5/2026
                              accountname = COND #( WHEN <lfs_glacc>-ItemNo = '2' or <lfs_glacc>-ItemNo = '5'
                                                THEN ls_gl_acc_data-glacc_name
                                                ELSE  <lfs_glacc>-value2 )
                              debit =   COND #( WHEN <lfs_glacc>-ItemNo = '1' OR <lfs_glacc>-ItemNo = '3'
                                                     OR <lfs_glacc>-ItemNo = '5'
                                                THEN 0
                                                WHEN  <lfs_glacc>-ItemNo = '2' OR <lfs_glacc>-ItemNo = '4'
*                                                THEN  lt_delvSo[ 1 ]-NetAmount   )
                                                THEN  lv_applied_gross_amt   )
                              credit = COND #( WHEN <lfs_glacc>-ItemNo = '1'
                                                THEN lv_Amounttoadjust
                                               WHEN <lfs_glacc>-ItemNo = '5'
                                                THEN lv_applied_gross_amt "lt_delvSo[ 1 ]-NetAmount
                                                 WHEN <lfs_glacc>-ItemNo = '3'
                                                THEN lv_tax_amount
                                                WHEN  <lfs_glacc>-ItemNo = '2' OR <lfs_glacc>-ItemNo = '4'
                                                THEN  0  )
                              currencycd = COND #( WHEN <lfs_glacc>-ItemNo = '1'
                                                THEN lv_keys-delvcurrency
                                                WHEN  <lfs_glacc>-ItemNo = '2' OR <lfs_glacc>-ItemNo = '3' OR <lfs_glacc>-ItemNo = '4' OR <lfs_glacc>-ItemNo = '5'
                                                THEN  lv_prepaycurr   )
                              wbselement = COND #( WHEN  <lfs_glacc>-ItemNo = '1'
                                                    THEN lt_delvSo[ 1 ]-wbs
                                                    ELSE lt_prepaySo[ 1 ]-wbs )
                                                     ).
        APPEND ls_data_prv TO lt_result.
        APPEND VALUE #( %cid_ref = keys[ 1 ]-%cid_ref
                       journalentry = '1000000001'
                       journalitem = '00001'
                       %param = CORRESPONDING #( ls_data_prv ) ) TO result.
        lv_journalitem += 1.
      ENDLOOP.
    ENDIF.
    " Scenario A
    IF lv_category = 'A'.
      SORT lt_glacc BY ItemNo.


      DATA: lv_taxrate          TYPE p LENGTH 16 DECIMALS 9,
            lv_applied_grossamt TYPE p LENGTH 16 DECIMALS 2,
            lv_taxamount        TYPE p LENGTH 16 DECIMALS 2,
            lv_threshold        TYPE p LENGTH 16 DECIMALS 2.

      "Get Tax Rate from SalesOrderItem
      SELECT SINGLE
          I_SalesDocItemPricingElement~ConditionRateValue
     FROM I_SalesDocItemPricingElement WHERE salesdocument = @lv_DlvOrder
                            AND salesdocumentitem = @lv_DlvOrderItem
                            AND ConditionType = 'TTX1'
                INTO @lv_taxrate.

      "Calculate Tax Amount
      lv_taxamount = lv_Amounttoadjust * lv_taxrate / 100.
      lv_applied_grossamt = lv_Amounttoadjust + lv_taxamount.

      LOOP AT lt_glacc ASSIGNING FIELD-SYMBOL(<lfs_glacc_a>).
        ls_data_prv     = VALUE #(
                              journalentry = lv_journal
                              journalitem = lv_journalitem
                              salesorder = COND #( WHEN <lfs_glacc_a>-ItemNo = '1'
                                                THEN lv_keys-deliveryso
                                                WHEN  <lfs_glacc_a>-ItemNo = '2' OR <lfs_glacc_a>-ItemNo = '3' OR <lfs_glacc_a>-ItemNo = '4' OR <lfs_glacc_a>-ItemNo = '5'
                                                OR <lfs_glacc_a>-ItemNo = '6' OR <lfs_glacc_a>-ItemNo = '7'
                                                THEN  lv_PreOrder   )
*                              glaccount = <lfs_glacc_a>-value1
                                "Updated 6/5/2026
                                 glaccount = COND #( WHEN <lfs_glacc_a>-ItemNo = '2' or <lfs_glacc_a>-ItemNo = '6'
                                                THEN ls_gl_acc_data-glacc_number
                                                ELSE  <lfs_glacc_a>-value1 )
*                              accountname = <lfs_glacc_a>-value2
                                "Updated 6/5/2026
                                accountname = COND #( WHEN <lfs_glacc_a>-ItemNo = '2' or <lfs_glacc_a>-ItemNo = '6'
                                                THEN ls_gl_acc_data-glacc_name
                                                ELSE  <lfs_glacc_a>-value2 )
                              debit =   COND #( WHEN <lfs_glacc_a>-ItemNo = '1' OR <lfs_glacc_a>-ItemNo = '3'
                                                     OR <lfs_glacc_a>-ItemNo = '4' OR <lfs_glacc_a>-ItemNo = '6'
                                                THEN 0
                                                WHEN <lfs_glacc_a>-ItemNo = '2' OR <lfs_glacc_a>-ItemNo = '5'

*                                                THEN  lt_delvSo[ 1 ]-NetAmount   )
                                                THEN  lv_applied_grossamt
                                                WHEN   <lfs_glacc_a>-ItemNo = '7'
                                                THEN lv_taxamount )
                              credit = COND #( WHEN <lfs_glacc_a>-ItemNo = '1'
                                                THEN lv_Amounttoadjust
                                               WHEN <lfs_glacc_a>-ItemNo = '6'
                                                THEN lv_applied_grossamt "lt_delvSo[ 1 ]-NetAmount
                                                 WHEN <lfs_glacc_a>-ItemNo = '3'
                                                THEN lv_taxamount
                                                WHEN <lfs_glacc_a>-ItemNo = '4'
                                                THEN lv_taxamount
                                                WHEN  <lfs_glacc_a>-ItemNo = '2' OR <lfs_glacc_a>-ItemNo = '5'
                                                THEN  0  )
                              currencycd = COND #( WHEN <lfs_glacc_a>-ItemNo = '1'
                                                THEN lv_keys-delvcurrency
                                                WHEN  <lfs_glacc_a>-ItemNo = '2' OR <lfs_glacc_a>-ItemNo = '3' OR <lfs_glacc_a>-ItemNo = '4' OR <lfs_glacc_a>-ItemNo = '5'
                                                OR <lfs_glacc_a>-ItemNo = '6' OR <lfs_glacc_a>-ItemNo = '7'
                                                THEN  lv_prepaycurr   )
                              wbselement = COND #( WHEN  <lfs_glacc_a>-ItemNo = '1'
                                                    THEN lt_delvSo[ 1 ]-wbs
                                                    ELSE lt_prepaySo[ 1 ]-wbs )
                                                     ).

       ls_data_prv-debit  = convert_to_correct_amount(
                                  iv_amount   = ls_data_prv-debit
                                  iv_currency = ls_data_prv-currencycd ).
       ls_data_prv-credit  = convert_to_correct_amount(
                                  iv_amount   = ls_data_prv-credit
                                  iv_currency = ls_data_prv-currencycd ).

        APPEND ls_data_prv TO lt_result.
        APPEND VALUE #( %cid_ref = keys[ 1 ]-%cid_ref
                       journalentry = '1000000001'
                       journalitem = '00001'
                       %param = CORRESPONDING #( ls_data_prv ) ) TO result.
        lv_journalitem += 1.
      ENDLOOP.
*      DATA(lv_prepayremainingamt) = VALUE #( lt_data_tmp1[ 1 ]-PrepaymentRemainingAmount OPTIONAL ).
      " Simulate Prepayment Remaining Amount for this line - (25/11/2025)
      "Get all rows with prepayment request num and prepayment SO from main view
      DATA lv_index TYPE i.
      DATA lv_prepayment_net TYPE p DECIMALS 2.
      DATA lv_prepayremainingamt TYPE p DECIMALS 2.
      DATA lv_DelvRemainingamt TYPE p DECIMALS 2.
      DATA lv_sum TYPE p DECIMALS 2.

      SELECT
        PrepaymentNetAmount,
        PrepaymentRemainingAmount,
        DelvSoSalesDocument,
        DelvSoSalesDocumentItem,
        DelvRemainingAmount,
        AdjustedAmount
      FROM ZI_PREPAYMENT_DELIVERY_SO_KEY
      WHERE prepaymentreqnumprepayment = @lv_keys-prepaymentrequestp
      AND prepaymentso = @lv_keys-prepaymentso
      INTO TABLE @DATA(lt_posting_rows).

      "--- Find the row index of the *current* row we are simulating for
     IF sy-subrc = 0.
          READ TABLE lt_posting_rows WITH KEY
            DelvSoSalesDocument    = lv_DlvOrder
            DelvSoSalesDocumentItem = lv_DlvOrderItem
            TRANSPORTING NO FIELDS.

          lv_index = sy-tabix.

          lv_prepayment_net = lt_posting_rows[ lv_index ]-PrepaymentNetAmount.
          lv_DelvRemainingamt = lt_posting_rows[ lv_index ]-DelvRemainingAmount.
     ENDIF.

      "--- Sum AdjustedAmount of all previous rows
      IF lines( lt_posting_rows ) > 1.
        DATA ls_row LIKE LINE OF lt_posting_rows.


        LOOP AT lt_posting_rows INTO ls_row "#EC CI_NOORDER
             FROM 1
             TO lv_index - 1.
          lv_sum += ls_row-adjustedamount.
        ENDLOOP.
      ELSE.
        lv_sum = 0.
      ENDIF.

      "Calculate simulated prepayment remaining amount
      lv_prepayremainingamt = lv_prepayment_net - lv_sum.
      " END Simulate Prepayment Remaining Amount for this line - (25/11/2025)

*      DATA(lv_DelvRemainingamt) = VALUE #( lt_data_tmp1[ 1 ]-DelvRemainingAmount OPTIONAL ).
      IF  lv_DelvRemainingamt > lv_prepayremainingamt.
        lv_threshold = VALUE #( lt_rounding[ value1 = lv_salesorg ]-value2 OPTIONAL ).
        IF ( lv_DelvRemainingamt - lv_prepayremainingamt ) < lv_threshold.
          LOOP AT lt_glaccrndg ASSIGNING FIELD-SYMBOL(<fs_glaccrndg>).
            ls_data_prv     = VALUE #(
                                journalentry = lv_journal + 1
                                journalitem = lv_journalitem
                                salesorder = lv_keys-deliveryso

                                glaccount = <fs_glaccrndg>-value1
                                accountname = <fs_glaccrndg>-value2
                                debit =   COND #( WHEN <fs_glaccrndg>-ItemNo = '1'
                                                  THEN 0
                                                  WHEN <fs_glaccrndg>-ItemNo = '2'
                                                  THEN  lv_DelvRemainingamt - lv_prepayremainingamt
                                                 )
                                credit = COND #( WHEN <fs_glaccrndg>-ItemNo = '1'
                                                  THEN lv_DelvRemainingamt - lv_prepayremainingamt
                                                 WHEN <fs_glaccrndg>-ItemNo = '2'
                                                  THEN  0  )
                                currencycd = lv_keys-delvcurrency

                                wbselement = lt_delvSo[ 1 ]-wbs
                                writeoff = 'X'
                                                       ).
            APPEND ls_data_prv TO lt_result.
            APPEND VALUE #( %cid_ref = keys[ 1 ]-%cid_ref
                           journalentry = '1000000001'
                           journalitem = '00001'
                           %param = CORRESPONDING #( ls_data_prv ) ) TO result.
            lv_journalitem += 1.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDIF.

    " Scenario D1
    IF lv_category = 'D1'.
      SORT lt_glacc BY ItemNo.


      DATA: lv_tax_rate_d          TYPE p LENGTH 16 DECIMALS 9,
            lv_applied_gross_amt_d TYPE p LENGTH 16 DECIMALS 2,
            lv_tax_amount_d       TYPE p LENGTH 16 DECIMALS 2.

      "Get Tax Rate from SalesOrderItem
      SELECT SINGLE
          I_SalesDocItemPricingElement~ConditionRateValue
     FROM I_SalesDocItemPricingElement WHERE salesdocument = @lv_DlvOrder
                            AND salesdocumentitem = @lv_DlvOrderItem
                            AND ConditionType = 'TTX1'
                INTO @lv_tax_rate_d.

      "Calculate Tax Amount
      lv_tax_amount_d = lv_Amounttoadjust * lv_tax_rate_d / 100.
      lv_applied_gross_amt_d = lv_Amounttoadjust + lv_tax_amount_d.

      LOOP AT lt_glacc ASSIGNING FIELD-SYMBOL(<lfs_glacc_d>).

        ls_data_prv     = VALUE #(
                              journalentry = lv_journal
                              journalitem = lv_journalitem
                              salesorder = COND #( WHEN <lfs_glacc_d>-ItemNo = '1'
                                                THEN lv_keys-deliveryso
                                                WHEN  <lfs_glacc_d>-ItemNo = '2' OR <lfs_glacc_d>-ItemNo = '3' OR <lfs_glacc_d>-ItemNo = '4' OR <lfs_glacc_d>-ItemNo = '5'
                                                THEN  lv_PreOrder   )
*                              glaccount = <lfs_glacc>-value1
                                "Updated 6/5/2026
                              glaccount = COND #( WHEN <lfs_glacc_d>-ItemNo = '2' or <lfs_glacc_d>-ItemNo = '5'
                                                THEN ls_gl_acc_data-glacc_number
                                                ELSE  <lfs_glacc_d>-value1 )
*                              accountname = <lfs_glacc>-value2
                                "Updated 6/5/2026
                              accountname = COND #( WHEN <lfs_glacc_d>-ItemNo = '2' or <lfs_glacc_d>-ItemNo = '5'
                                                THEN ls_gl_acc_data-glacc_name
                                                ELSE  <lfs_glacc_d>-value2 )
                              debit =   COND #( WHEN <lfs_glacc_d>-ItemNo = '1' OR <lfs_glacc_d>-ItemNo = '3'
                                                     OR <lfs_glacc_d>-ItemNo = '5'
                                                THEN 0
                                                WHEN  <lfs_glacc_d>-ItemNo = '2' OR <lfs_glacc_d>-ItemNo = '4'
*                                                THEN  lt_delvSo[ 1 ]-NetAmount   )
                                                THEN  lv_applied_gross_amt_d   )
                              credit = COND #( WHEN <lfs_glacc_d>-ItemNo = '1'
                                                THEN lv_Amounttoadjust
                                               WHEN <lfs_glacc_d>-ItemNo = '5'
                                                THEN lv_applied_gross_amt_d "lt_delvSo[ 1 ]-NetAmount
                                                 WHEN <lfs_glacc_d>-ItemNo = '3'
                                                THEN lv_tax_amount_d
                                                WHEN  <lfs_glacc_d>-ItemNo = '2' OR <lfs_glacc_d>-ItemNo = '4'
                                                THEN  0  )
                              currencycd = COND #( WHEN <lfs_glacc_d>-ItemNo = '1'
                                                THEN lv_keys-delvcurrency
                                                WHEN  <lfs_glacc_d>-ItemNo = '2' OR <lfs_glacc_d>-ItemNo = '3' OR <lfs_glacc_d>-ItemNo = '4' OR <lfs_glacc_d>-ItemNo = '5'
                                                THEN  lv_prepaycurr   )
                              wbselement = COND #( WHEN  <lfs_glacc_d>-ItemNo = '1'
                                                    THEN lt_delvSo[ 1 ]-wbs
                                                    ELSE lt_prepaySo[ 1 ]-wbs )
                                                     ).
        APPEND ls_data_prv TO lt_result.
        APPEND VALUE #( %cid_ref = keys[ 1 ]-%cid_ref
                       journalentry = '1000000001'
                       journalitem = '00001'
                       %param = CORRESPONDING #( ls_data_prv ) ) TO result.
        lv_journalitem += 1.
      ENDLOOP.
    ENDIF.



  ENDMETHOD.
  METHOD fill_gl_item.

    DATA ls_glitem TYPE ty_glitem.

    DATA(lv_transaction_amount) = convert_to_correct_amount(
                                  iv_amount   = is_data-grossamount
                                  iv_currency = is_data-socurrency ).

    rs_item-%param-_glitems = VALUE #(

            (         glaccountlineitem        = iv_itemno
                   glaccount                = |{ iv_glacc ALPHA = IN }|
                   wbselement               = is_data-wbs

                   profitcenter             =  is_data-profitcenter
*                      costcenter               = SWITCH #( is_data-entity
*                                                    WHEN gc_buyer THEN is_header-companycode
*                                                    ELSE '' )
                   documentitemtext         = |Item { iv_itemno ALPHA = OUT }|
                   salesorder               = |{ is_data-salesorder ALPHA = IN }|
                   salesorderitem           = |{ is_data-salesorderitem ALPHA = IN }|
                   functionalarea           = is_data-salesorg
*                      partnercompany = is_data-TradingPartner

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




  ENDMETHOD.

*  METHOD PrepayPost.
*
*    DATA: ls_entry  LIKE LINE OF gt_entry,
*          lv_itemno TYPE n LENGTH 6.
*    DATA: lt_entry TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
*          lo_msg   TYPE REF TO if_abap_behv_message.
*    DATA: gv_date TYPE d,
*          gv_time TYPE t.
*    CONSTANTS: lc_documenttype        TYPE i_journalentry-accountingdocumenttype VALUE 'AD',
*               lc_transactiontype     TYPE i_journalentry-businesstransactiontype VALUE 'RFBU',
*               lc_documentreferenceid TYPE i_journalentry-documentreferenceid VALUE 'BKPFF'.
*    DATA(lv_keys) = keys[ 1 ]-%param.
*    DATA(lv_Order) = lv_keys-salesorder.
*    DATA(lv_OrderItem) = lv_keys-salesorderitem.
**    DATA: lt_data_prv TYPE table for read RESULT ZC_PREPAYMENT_PREVIEW ,
**          ls_data_prv type zi_preview_result.
*    DATA: lt_data_tmp  TYPE STANDARD TABLE OF zc_prepayment_delivery_so,
*          lt_result    TYPE TABLE FOR READ RESULT zc_prepayment_preview,
*          ls_data_prv  LIKE LINE OF lt_result,
*          ls_post_data TYPE zstprepayglitem.
*
*    DATA: lv_journal     TYPE i,
*          lv_journalitem TYPE i.
*    "Select Data for the Prepayment Data
*    SELECT
*           zc_prepayment_delivery_so~prepaymentreqnumprepayment AS prepaymentrequest,
*           zc_prepayment_delivery_so~prepaymentso AS salesorder,
*           zc_prepayment_delivery_so~prepaymentsoitem AS salesorderitem,
*           zc_prepayment_delivery_so~prepaymentsalesorg AS salesorg,
*           zc_prepayment_delivery_so~prepaymentsoldto AS soldto,
*           zc_prepayment_delivery_so~prepaymentscenariopy AS scenario,
*           zc_prepayment_delivery_so~prepaymentsditemctgy AS itemctgy,
*           zc_prepayment_delivery_so~prepaymentcurrency AS socurrency,
*           zc_prepayment_delivery_so~prepaymentgrossamount AS grossamount,
*           PrePaySO~ProfitCenter AS profitcenter,
*           PrePaySO~YY1_StatWBSExt_SDI AS wbs
**           zc_prepayment_delivery_so~delvsosalesdocument,
**           zc_prepayment_delivery_so~delvsosalesdocumentitem,
**           zc_prepayment_delivery_so~delvsosalesorg,
**           zc_prepayment_delivery_so~delvsosoldto,
**           zc_prepayment_delivery_so~delvsoscenario,
**           zc_prepayment_delivery_so~delvsosditmctgy,
**           zc_prepayment_delivery_so~delvsocurrency,
**           zc_prepayment_delivery_so~delvsoamount,
**           DelvSO~ProfitCenter as ProfitCenter_DS,
**           DelvSO~YY1_StatWBSExt_SDI as WBS_DS
*  FROM
*   zc_prepayment_delivery_so
*   LEFT OUTER JOIN I_SalesDocumentItem AS PrePaySO
*   ON zc_prepayment_delivery_so~PrepaymentSO = PrePaySo~SalesDocument
*   AND zc_prepayment_delivery_so~prepaymentsoitem = PrePaySo~SalesDocumentItem
*  WHERE prepaymentreqnumprepayment = @lv_keys-prepaymentrequestp
*    INTO TABLE @DATA(lt_data_prepay)  .
*
*    SELECT
*          zc_prepayment_delivery_so~prepaymentreqnumprepayment,
*          zc_prepayment_delivery_so~delvsosalesdocument,
*          zc_prepayment_delivery_so~delvsosalesdocumentitem,
*          zc_prepayment_delivery_so~delvsosalesorg,
*          zc_prepayment_delivery_so~delvsosoldto,
*          zc_prepayment_delivery_so~delvsoscenario,
*          zc_prepayment_delivery_so~delvsosditmctgy,
*          zc_prepayment_delivery_so~delvsocurrency,
*          zc_prepayment_delivery_so~delvsoamount,
*          DelvSO~ProfitCenter AS ProfitCenter,
*          DelvSO~YY1_StatWBSExt_SDI AS wbs
* FROM
*  zc_prepayment_delivery_so
*  LEFT OUTER JOIN I_SalesDocumentItem AS DelvSO
*  ON zc_prepayment_delivery_so~delvsosalesdocument = DelvSO~SalesDocument
*  AND zc_prepayment_delivery_so~delvsosalesdocumentitem = DelvSO~SalesDocumentItem
* WHERE prepaymentreqnumprepayment = @lv_keys-prepaymentrequestp
*   INTO TABLE @DATA(lt_data_DelvSo)  .
*    "Prepare the result of Post
*    lv_journal = lv_journalitem = 1.
*    gv_date = cl_abap_context_info=>get_system_date( ).
*    gv_time = cl_abap_context_info=>get_system_time( ).
*
*    LOOP AT lt_data_prepay INTO DATA(ls_header)
*         GROUP BY ( prepaymentreqnumprepayment = ls_header-prepaymentrequest ).
*
*      "Header
*      DATA(lo_generator) = cl_uuid_factory=>create_system_uuid( ).
*      TRY.
*          ls_entry-%cid = lo_generator->create_uuid_x16( ).
*        CATCH cx_uuid_error ##NO_HANDLER.
*      ENDTRY.
*      ls_entry-%param-companycode = ls_header-salesorg.
*      ls_entry-%param-accountingdocumentheadertext = |Prepayment Posting|.
*      ls_entry-%param-documentdate = gv_date.
*      ls_entry-%param-postingdate = gv_date.
*      ls_entry-%param-taxdeterminationdate = gv_date.
*      ls_entry-%param-createdbyuser = sy-uname.
*      ls_entry-%param-businesstransactiontype = lc_transactiontype.
*      ls_entry-%param-documentreferenceid = lc_documentreferenceid.
*      ls_entry-%param-accountingdocumenttype = lc_documenttype.
*      "Items
*      ls_post_data = CORRESPONDING #( ls_header ).
*      lv_itemno = lv_itemno + 1.
*      DATA(ls_glitem1) = fill_gl_item( is_data = ls_post_data
*                                       iv_itemno = lv_itemno
*                                       iv_glacc = '2107010200'
*                                       iv_debitcredit = 'S' ).
*      ls_entry-%param-_glitems =  ls_glitem1-%param-_glitems.
*      CLEAR : ls_post_data.
*      LOOP AT  lt_data_DelvSo INTO DATA(ls_delvso).
*        ls_post_data = CORRESPONDING #( ls_delvso ).
*        lv_itemno = lv_itemno + 1.
*        DATA(ls_glitem2) = fill_gl_item( is_data = ls_post_data
*                                         iv_itemno = lv_itemno
*                                         iv_glacc = '1107200100'
*                                         iv_debitcredit = 'H').
*        ls_entry-%param-_glitems =  ls_glitem2-%param-_glitems.
*      ENDLOOP.
*      APPEND ls_entry TO gt_entry.
*    ENDLOOP.
** post Journal entries
*    IF gt_entry IS NOT INITIAL.
*      MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
*        ENTITY journalentry
*        EXECUTE post FROM gt_entry
*        MAPPED FINAL(ls_post_mapped)
*        FAILED FINAL(ls_post_failed)
*        REPORTED FINAL(ls_post_reported).
*
*      IF sy-subrc = 0.
*
*        LOOP AT ls_post_mapped-journalentry INTO DATA(ls_accounting).
**   APPEND VALUE #( accountingdocument = ls_accounting-accountingDocument ) TO result.
*        ENDLOOP.
*      ENDIF.
*    ENDIF.
*  ENDMETHOD.

  METHOD get_gl_account.
          SELECT SINGLE
            cc~ReconciliationAccount AS glacc_number,
            sk~GLAccountName         AS glacc_name
          FROM I_CustomerCompany AS cc
          INNER JOIN i_glaccounttext AS sk
            ON  sk~GLAccount = cc~ReconciliationAccount
            AND sk~Language = 'E'
          WHERE cc~CompanyCode = @iv_salesorg
            AND cc~Customer    = @iv_customer
          INTO @rs_glacc.
  ENDMETHOD.

ENDCLASS.
