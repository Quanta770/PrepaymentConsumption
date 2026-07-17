*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS lcl_updatepayment_event DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.

    METHODS update_event FOR ENTITY EVENT changed_instances FOR I_JournalEntryTP~created.

    METHODS post_cpi
      IMPORTING
        iv_accounting_document TYPE belnr_d
        iv_company_code        TYPE bukrs
        iv_fiscal_year         TYPE gjahr
        iv_accdoctype            TYPE blart
        iv_collection_number   TYPE string
        iv_customer            TYPE kunnr.
    TYPES ty_customer_type TYPE c LENGTH 8.
    METHODS check_customer_type
        IMPORTING
        iv_company_code TYPE bukrs
        iv_customer TYPE kunnr
        RETURNING
        VALUE(rv_customer_type) TYPE ty_customer_type.


ENDCLASS.

CLASS lcl_updatepayment_event IMPLEMENTATION.

  METHOD update_event.

    DATA:
      lv_prefix   TYPE string,
      lv_number   TYPE string,
      lv_int      TYPE i,
      lv_result   TYPE string,
      lv_indx     TYPE string,
      lv_temp_int TYPE string.


    READ ENTITIES OF I_JournalEntryTP
          ENTITY  JournalEntry
            ALL FIELDS
            WITH VALUE #( FOR ls_changed_instance IN changed_instances
                           ( AccountingDocument = ls_changed_instance-AccountingDocument
                             CompanyCode = ls_changed_instance-CompanyCode
                             FiscalYear = ls_changed_instance-Fiscalyear ) )
          RESULT DATA(lt_Journal)
          FAILED DATA(lt_failed)
          REPORTED DATA(lt_reported).

    DATA(ls_journal) = VALUE #( lt_Journal[ 1 ] OPTIONAL ).
    SELECT SINGLE isreversal
       FROM I_journalentryitem
       WHERE AccountingDocument = @ls_journal-AccountingDocument
                   AND           CompanyCode = @ls_journal-CompanyCode
                   AND           FiscalYear = @ls_journal-Fiscalyear
         INTO @DATA(lv_reversal).

    "START change for collection invoice credit note full reversal scenario - 17/4/2026
    IF lv_reversal IS NOT INITIAL.
      SELECT SINGLE
           Value1
        FROM zi_config_values_read
        WHERE parameterid = 'CNOrgInvNum'
        AND category = @ls_journal-CompanyCode
        INTO @DATA(lv_flag_cn).

      "Check if the scenario is enabled for the company code and document type
      IF lv_flag_cn = 'TRUE' AND ls_journal-AccountingDocumentType = 'D9'.
        "Original Collection Invoice number in Document Header Text: 6/4/2026
        DATA: lt_je_rv  TYPE TABLE FOR ACTION IMPORT i_journalentrytp~change,
              lv_cid_rv TYPE abp_behv_cid.

        TRY.
            lv_cid_rv = to_upper( cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ) ).
          CATCH cx_uuid_error.
            ASSERT 1 = 0.
        ENDTRY.
        APPEND INITIAL LINE TO lt_je_rv ASSIGNING FIELD-SYMBOL(<je_rv>).
        DATA ls_header_control_rev LIKE <je_rv>-%param-%control.
        ls_header_control_rev-documentheadertext = if_abap_behv=>mk-on.

        SELECT SINGLE CollectionInvoiceNumber, jei~ClearingJournalEntry
        FROM I_JournalEntry AS je
        INNER JOIN zi_collection_inv_num AS collection
        ON collection~AccountingDocument = je~ReverseDocument
        AND collection~Fiscalyear = je~reversedocumentfiscalyear
        AND collection~companycode =  @ls_journal-CompanyCode
        INNER JOIN I_JournalentryItem AS jei
         ON   je~accountingdocument = jei~AccountingDocument
        AND   je~CompanyCode = jei~CompanyCode
        AND   je~FiscalYear = jei~Fiscalyear
        WHERE je~accountingdocument = @ls_journal-AccountingDocument
        AND   je~CompanyCode = @ls_Journal-CompanyCode
        AND   je~FiscalYear = @ls_Journal-Fiscalyear
*        INTO ( @DATA(lv_collectioninv) ).
        INTO ( @DATA(lv_collectioninv) , @DATA(lv_clearingdocument) ).

        "Update only only if collection invoice number is found for the reversal document
        IF lv_collectioninv IS NOT INITIAL OR lv_clearingdocument IS NOT INITIAL.
*        IF sy-subrc = 0.
          <je_rv>-accountingdocument = ls_journal-AccountingDocument .
          <je_rv>-fiscalyear = ls_journal-FiscalYear.
          <je_rv>-companycode = ls_journal-CompanyCode.
          <je_rv>-%param = VALUE #(
           documentheadertext = lv_collectioninv
           %control = ls_header_control_rev  ) .

          MODIFY ENTITIES OF i_journalentrytp
           ENTITY journalentry
           EXECUTE change FROM lt_je_rv
           FAILED DATA(ls_failed_deep_rev)
           REPORTED DATA(ls_reported_deep_rev)
           MAPPED DATA(ls_mapped_deep_rev).

        ENDIF.

      ENDIF.

    ENDIF.
    "END change for collection invoice credit note full reversal scenario - 17/4/2026



    SELECT SINGLE
      Value1, Value2
   FROM zi_config_values_read
   WHERE parameterid = 'AccDocType'
   AND category = @ls_journal-CompanyCode
   AND value1 = @ls_journal-accountingdocumenttype
   INTO ( @DATA(lv_accdoctype) , @DATA(lv_enh) ).



    SELECT SINGLE
       Value1,Value2
    FROM zi_config_values_read
    WHERE parameterid = 'AccDocType_CR'
    AND category = @ls_journal-CompanyCode
    AND value1 = @ls_journal-accountingdocumenttype
    INTO (  @DATA(lv_accdoctype_cr) ,@DATA(lv_enh_cr) ).

    CHECK lv_enh = 'EVENT' OR lv_enh_cr = 'EVENT'.

    SELECT SINGLE

          je2~accountingdocumenttype

       FROM i_journalentry AS je1
       LEFT OUTER JOIN i_journalentry AS je2
       ON je1~ReversalReferenceDocument = je2~AccountingDocument
       AND je1~CompanyCode = je2~CompanyCode
       AND je1~ReverseDocumentFiscalYear = je2~FiscalYear
       WHERE je1~AccountingDocument = @ls_Journal-AccountingDocument
                AND   je1~CompanyCode = @ls_Journal-CompanyCode
                AND   je1~FiscalYear = @ls_Journal-Fiscalyear
        INTO @DATA(lv_reversal_docType)   .


    IF (  lv_accdoctype IS NOT INITIAL  AND lv_reversal IS INITIAL ) OR
        ( lv_accdoctype_cr IS NOT INITIAL AND lv_reversal IS INITIAL ) OR
       ( lv_accdoctype_cr IS NOT INITIAL AND lv_reversal IS NOT INITIAL AND lv_reversal_docType = 'D8') OR
       ( lv_accdoctype_cr IS NOT INITIAL AND lv_reversal IS NOT INITIAL AND lv_reversal_docType = 'DZ').

        "Collection credit note
        IF lv_accdoctype_cr IS NOT INITIAL.
            "=============================================================================
            " Payment Reference Resolution Logic
            " Handles all cancellation scenarios per requirements:
            "   1.1  Full cancel - Reversal        → PayRef exists in DZ/D8/D9
            "   1.2  Full cancel - Post D9         → PayRef INITIAL in D9, NOT INITIAL in DZ/D8
            "                                        ClearingJournalEntry IS NOT INITIAL  (Option 4)
            "   2.1  Partial cancel - Post D9      → PayRef exists in DZ/D8, D9 less than 100
            "                                        ClearingJournalEntry IS INITIAL on D9 line
            "=============================================================================

              DATA: lv_payref     TYPE c LENGTH 30,   " PaymentReference from DZ/D8
                    lv_payrefd9   TYPE c LENGTH 30,   " PaymentReference from D9 (via JOIN)
                    lv_customer   TYPE c LENGTH 10,
                    lv_cje        TYPE c LENGTH 10,   " ClearingJournalEntry captured for 1.2 detection
                    lv_scenario12 TYPE abap_bool,     " Flag: scenario 1.2 detected
                    lv_precheck   TYPE c LENGTH 30,
                    lv_refcheck   TYPE c LENGTH 10.

              CLEAR: lv_payref, lv_payrefd9, lv_customer, lv_cje,
                     lv_scenario12, lv_precheck, lv_refcheck.


              SELECT SINGLE
                     pr1~PaymentReference,
                     pr2~PaymentReference   AS PayRefD9,
                     pr1~Customer,
                     pr1~ClearingJournalEntry  " <-- NEW: needed to detect scenario 1.2
                FROM I_OperationalAcctgDocItem AS pr1
                LEFT OUTER JOIN I_OperationalAcctgDocItem AS pr2
                  ON pr2~ClearingJournalEntry        = pr1~ClearingJournalEntry
                 AND pr2~CompanyCode                 = pr1~CompanyCode
                 AND pr2~ClearingJournalEntryFiscalYear = pr1~ClearingJournalEntryFiscalYear
                 AND pr2~PaymentReference IS NOT INITIAL   " only matches D9 when PayRef exists (1.1)
               WHERE pr1~AccountingDocument = @ls_Journal-AccountingDocument
                 AND pr1~CompanyCode        = @ls_Journal-CompanyCode
                 AND pr1~FiscalYear         = @ls_Journal-Fiscalyear
                 AND pr1~ClearingJournalEntry IS NOT INITIAL
                INTO (@lv_payref, @lv_payrefd9, @lv_customer, @lv_cje).

            "-----------------------------------------------------------------------------
            " Step 2: Scenario 1.2 detection (NEW)
            "
            "   Condition:
            "     - ClearingJournalEntry IS NOT INITIAL  → this is a full-cancel Post D9, not partial
            "     - lv_payrefd9   IS INITIAL             → D9 has no PaymentReference
            "     - lv_payref     IS NOT INITIAL         → DZ/D8 does have PaymentReference
            "
            "-----------------------------------------------------------------------------
                IF lv_payrefd9 IS INITIAL AND lv_payref IS NOT INITIAL AND lv_cje IS NOT INITIAL.
                    SELECT SINGLE
                         currentdoc~PaymentReference,
                         originaldoc~PaymentReference   AS PayRefD9,
                         currentdoc~Customer
                    FROM I_OperationalAcctgDocItem AS currentdoc
                    LEFT OUTER JOIN I_OperationalAcctgDocItem AS originaldoc
                      ON originaldoc~ClearingJournalEntry        = currentdoc~ClearingJournalEntry
                     AND originaldoc~CompanyCode                 = currentdoc~CompanyCode
                     AND originaldoc~ClearingJournalEntryFiscalYear = currentdoc~ClearingJournalEntryFiscalYear
                   WHERE currentdoc~AccountingDocument = @ls_Journal-AccountingDocument
                     AND currentdoc~CompanyCode        = @ls_Journal-CompanyCode
                     AND currentdoc~FiscalYear         = @ls_Journal-Fiscalyear
                     AND currentdoc~ClearingJournalEntry IS NOT INITIAL
                    INTO (@lv_payref, @lv_payrefd9, @lv_customer).


                ENDIF.
            "-----------------------------------------------------------------------------
            " Step 3: Partial reversal fallback (scenario 2.1)
            "
            "   Reached when:
            "     - lv_payref   IS INITIAL  (DZ/D8 line had no PayRef via the JOIN path)
            "     - lv_payrefd9 IS INITIAL  (D9 also had none)
            "   This means ClearingJournalEntry was INITIAL on the relevant line, i.e.
            "   the D9 posting is partial (amount < 100) and has not yet been cleared.
            "-----------------------------------------------------------------------------

                  "Partial reversal case
                  IF lv_payref IS INITIAL AND lv_payrefd9 IS INITIAL AND lv_cje IS INITIAL.
                    SELECT SINGLE PaymentReference, customer
                        FROM I_OperationalAcctgDocItem
                        WHERE AccountingDocument = @ls_Journal-AccountingDocument
                          AND CompanyCode        = @ls_Journal-CompanyCode
                          AND FiscalYear         = @ls_Journal-Fiscalyear
                          AND ClearingJournalEntry IS INITIAL
                          AND InvoiceReference IS NOT INITIAL
                        INTO (@lv_payrefd9, @lv_customer).
                  ENDIF.

        ENDIF.
        "Collection Invoice
        IF lv_accdoctype IS NOT INITIAL.
            SELECT SINGLE PaymentReference, customer
            FROM I_OperationalAcctgDocItem
            WHERE AccountingDocument = @ls_Journal-AccountingDocument
              AND CompanyCode        = @ls_Journal-CompanyCode
              AND FiscalYear         = @ls_Journal-Fiscalyear
              AND ClearingJournalEntry IS INITIAL
              AND PaymentReference IS NOT INITIAL
            INTO (@lv_payref, @lv_customer).

        ENDIF.

"-----------------------------------------------------------------------------
" Step 4: Standard reference resolution (scenarios 1.1 and 2.1)
"
"   lv_precheck picks the best available reference:
"     - Prefer lv_payref (DZ/D8) when populated (covers 1.1 where both are set,
"       and 2.1 where only lv_payref is set after the fallback SELECT).
"     - Fall back to lv_payrefd9 (D9) if DZ/D8 has none.
"
"   lv_refcheck slices the reference per document type:
"     - Standard doc type  → characters 1–3  (+0(3))
"     - Credit doc type    → characters 2–3  (+1(2))
"-----------------------------------------------------------------------------

     lv_precheck  = COND #( WHEN lv_payref IS INITIAL
                                   THEN lv_payrefd9
                                   ELSE lv_payref ).
      lv_refcheck  = COND #( WHEN lv_accdoctype = ls_journal-accountingdocumenttype
                                  THEN lv_precheck+0(3)
                                  WHEN lv_accdoctype_cr = ls_journal-accountingdocumenttype
                                  THEN lv_precheck+1(2) ).
* Check if Collection invoice already updated
      SELECT SINGLE
           CASE WHEN
           Reference3IDByBusinessPartner IS  INITIAL
           THEN Reference1IDByBusinessPartner
           ELSE Reference3IDByBusinessPartner
           END
           FROM I_OperationalAcctgDocItem
           WHERE AccountingDocument = @ls_Journal-AccountingDocument
              AND   CompanyCode = @ls_Journal-CompanyCode
              AND   FiscalYear = @ls_Journal-Fiscalyear
              AND customer IS NOT INITIAL
            INTO @DATA(lv_Ref3ID).
* Check which Ref field to update

      SELECT SINGLE
          category
       FROM zi_config_values_read
       WHERE parameterid = 'InvoiceRef'
       AND category = @ls_Journal-CompanyCode
       INTO @DATA(lv_refid).


* Collection Invoice Number
      SELECT SINGLE jr~reference3
        FROM  zi_collectioninv_main WITH PRIVILEGED ACCESS AS jr
        WHERE jr~CompanyCode = @ls_Journal-CompanyCode
          AND jr~FiscalYear = @ls_Journal-fiscalyear
          AND jr~ref2check = @lv_refcheck
          INTO @DATA(lv_reference3_DZ).

      SELECT SINGLE jr~reference3
        FROM  zi_collectioninv_cr_main WITH PRIVILEGED ACCESS AS jr
        WHERE jr~CompanyCode = @ls_Journal-CompanyCode
          AND jr~FiscalYear = @ls_Journal-fiscalyear
          AND jr~ref2check = @lv_refcheck
          INTO @DATA(lv_reference3_D9).

      DATA(lv_reference3) = COND #( WHEN lv_accdoctype = ls_journal-accountingdocumenttype
                                      THEN lv_reference3_DZ
                                      WHEN lv_accdoctype_cr = ls_journal-accountingdocumenttype
                                      THEN lv_reference3_D9 ).

      IF lv_reference3 IS NOT INITIAL.
        lv_prefix = COND #( WHEN lv_accdoctype = ls_journal-accountingdocumenttype
                                      THEN lv_reference3+0(3)
                                      WHEN lv_accdoctype_cr = ls_journal-accountingdocumenttype
                                      THEN lv_reference3+0(2) ).


        lv_number = COND #( WHEN lv_accdoctype = ls_journal-accountingdocumenttype
                                      THEN lv_reference3+3
                                      WHEN lv_accdoctype_cr = ls_journal-accountingdocumenttype
                                      THEN lv_reference3+2 ).


        lv_int = lv_number.

        lv_int = lv_int + 1.

        lv_temp_int = lv_int.

        DATA(lv_temp_str) = |{ lv_temp_int ALPHA = IN WIDTH = 8  } |.

        lv_reference3 = COND #( WHEN ls_journal-accountingdocumenttype = lv_accdoctype_cr
                               THEN lv_prefix &&  lv_temp_str
                               ELSE lv_prefix && lv_int  ).


        CLEAR lv_indx.

        "Update Reference3ByPartnerID
        DATA: lt_je  TYPE TABLE FOR ACTION IMPORT i_journalentrytp~change,
              lv_cid TYPE abp_behv_cid.

        TRY.
            lv_cid = to_upper( cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ) ).
          CATCH cx_uuid_error.
            ASSERT 1 = 0.
        ENDTRY.
        APPEND INITIAL LINE TO lt_je ASSIGNING FIELD-SYMBOL(<je>).

*         Header Control
        DATA ls_header_control LIKE <je>-%param-%control.
*      ls_header_control-documentheadertext = if_abap_behv=>mk-on.
        ls_header_control-documentreferenceid = if_abap_behv=>mk-on.

        "Original Collection Invoice number in Document Header Text: 6/4/2026
*        IF lv_reversal IS NOT INITIAL.
*            ls_header_control-documentheadertext = if_abap_behv=>mk-on.
*
*            SELECT SINGLE CollectionInvoiceNumber
*            FROM I_JournalEntry as je
*            INNER JOIN ZI_COLLECTION_INV_NUM as collection
*            ON collection~AccountingDocument = je~ReverseDocument
*            AND collection~Fiscalyear = je~reversedocumentfiscalyear
*            AND collection~companycode =  @ls_journal-CompanyCode
*            WHERE je~accountingdocument = @ls_journal-AccountingDocument
*            AND   je~CompanyCode = @ls_Journal-CompanyCode
*            AND   je~FiscalYear = @ls_Journal-Fiscalyear
*            INTO @DATA(lv_collectioninv).
*
*        ENDIF.



        <je>-accountingdocument = ls_journal-AccountingDocument .
        <je>-fiscalyear = ls_journal-FiscalYear.
        <je>-companycode = ls_journal-CompanyCode.
        <je>-%param = VALUE #(

*       documentheadertext = COND #( WHEN lv_Ref3ID IS INITIAL
*                                      THEN lv_reference3
*                                      ELSE lv_Ref3ID )

*           documentreferenceid = COND #( WHEN lv_Ref3ID IS INITIAL
*                                          THEN lv_reference3
*                                          ELSE lv_Ref3ID )
         documentreferenceid = lv_reference3
*         documentheadertext = lv_collectioninv
         %control = ls_header_control  ) .

        MODIFY ENTITIES OF i_journalentrytp
         ENTITY journalentry
         EXECUTE change FROM lt_je
         FAILED DATA(ls_failed_deep)
         REPORTED DATA(ls_reported_deep)
         MAPPED DATA(ls_mapped_deep).

        " read the response from the API and respond back the result accordingly

        IF ls_failed_deep IS NOT INITIAL.
          "ROLLBACK ENTITIES.
        ELSE.
            post_cpi(
              iv_accounting_document = ls_journal-AccountingDocument
              iv_company_code        = ls_journal-CompanyCode
              iv_fiscal_year         = ls_journal-FiscalYear
              iv_accdoctype         = ls_journal-accountingdocumenttype
              iv_collection_number   = CONV string( lv_reference3 )
              iv_customer        = lv_customer
            ).
        ENDIF.
      ENDIF.
    ENDIF.




  ENDMETHOD.

      METHOD post_cpi.
        DATA: lv_csrf_token  TYPE string,
              lv_session     TYPE string,
              lv_json_string TYPE string.


        SELECT SINGLE
             Category, Value1, Value2, Value3
          FROM zi_config_values_read
          WHERE parameterid = 'PrepayColConfig'
          AND category = @iv_company_code
          INTO @DATA(ls_config).

          CHECK sy-subrc = 0  AND ls_config-Value1 = 'ACTIVE'.



        "Get Output type
        DATA: lv_output_type TYPE c LENGTH 10.
        DATA lv_cust_type TYPE c LENGTH 10.
        IF ls_config-Value3 = 'CHECK_CUSTOMER_TYPE_TRUE'.
            lv_cust_type = check_customer_type(
                                  iv_company_code = iv_company_code
                                  iv_customer = iv_customer ).
             DATA(lv_param_id) = |{ iv_company_code }_CustCheck|.

             DATA(lv_cust_type_upper) = to_upper( lv_cust_type ).

            SELECT SINGLE
                value1
              FROM zi_config_values_read
              WHERE parameterid = @lv_param_id
                AND category   = @lv_cust_type_upper
              INTO @lv_output_type.
        ELSE.
            lv_output_type = ls_config-Value2.

        ENDIF.


          DATA(tenant) = xco_cp=>current->tenant( ).
          IF tenant IS BOUND.
            DATA(ui_url) = tenant->get_url(
            xco_cp_tenant=>url_type->ui ).
            DATA(lv_host) = ui_url->get_host( ).
          ENDIF.




          TRY.

              DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                        comm_scenario = 'ZCS_COLLECTION_INVOICE'
                                        service_id    = 'ZOS_COLLECTION_INV_CPI_REST' ).

              DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination(
                                        i_destination = lo_destination ).

              lo_http_client->accept_cookies( abap_true ).

              " --- Step 1: CSRF token fetch ---
              DATA(lo_request) = lo_http_client->get_http_request( ).
              lo_request->set_content_type( 'application/json' ).
              lo_request->set_header_fields( VALUE #(
                  ( name = 'X-CSRF-Token' value = 'fetch' ) ) ).

              DATA(lo_response) = lo_http_client->execute( i_method = if_web_http_client=>get ).

              lv_csrf_token = lo_response->get_header_field( 'X-CSRF-Token' ).
              lv_session    = lo_response->get_header_field( 'set-cookie' ).

              IF lv_csrf_token IS INITIAL.
                RAISE EXCEPTION TYPE zcx_cpi_post_error
                  EXPORTING
                    textid = zcx_cpi_post_error=>csrf_fetch_failed.
              ENDIF.

              "Get Collection Invoice Number
*              SELECT SINGLE CollectionInvoiceNumber, accountingdocumenttype
*              FROM zi_collection_inv_num
*              WHERE accountingdocument = @iv_accounting_document
*              AND fiscalyear = @iv_fiscal_year
*              AND companycode = @iv_company_code
*              INTO ( @DATA(lv_collection_invoice), @DATA(lv_doc_type) ).

              SELECT SINGLE SalesDocument,SalesDocumentItem, YY1_SALESFORCEID_I_SDI
                FROM ZC_Prepayment_CollectionStatus
                WHERE AccountingDocument = @iv_accounting_document
                AND FiscalYear = @iv_fiscal_year
                AND CompanyCode = @iv_company_code
                INTO @DATA(ls_prepay_data).

              " --- Step 2: Build JSON payload ---
              DATA(lo_json_builder) = xco_cp_json=>data->builder( ).
              lo_json_builder->begin_object( ).
              lo_json_builder->add_member( 'environment' )->add_string( |{ lv_host }| ).
              lo_json_builder->add_member( 'output_type' )->add_string( |{ lv_output_type }| ).
              lo_json_builder->add_member( 'accounting_document' )->add_string( |{ iv_accounting_document }| ).
              lo_json_builder->add_member( 'fiscal_year' )->add_string( |{ iv_fiscal_year }| ).
              lo_json_builder->add_member( 'company_code' )->add_string( |{ iv_company_code }| ).
              lo_json_builder->add_member( 'customer' )->add_string( |{ iv_customer }| ).
              lo_json_builder->add_member( 'collection_invoice_number' )->add_string( |{ iv_collection_number }| ).
              lo_json_builder->add_member( 'accounting_document_type' )->add_string( |{ iv_accdoctype }| ).
              lo_json_builder->add_member( 'sfid' )->add_string( |{ ls_prepay_data-yy1_salesforceid_i_sdi }| ).
              lo_json_builder->add_member( 'salesdocument' )->add_string( |{ ls_prepay_data-SalesDocument }| ).
              lo_json_builder->add_member( 'salesdocumentitem' )->add_string( |{ ls_prepay_data-SalesDocumentItem }| ).


              IF lv_output_type = 'FORM'.
                "Generate PDF content as XSTRING
                  DATA(ls_pdf) = zcl_generate_pdf=>render_pdf(
                      iv_accounting_document = iv_accounting_document
                      iv_company_code        = iv_company_code
                      iv_fiscal_year         = iv_fiscal_year
                    ).

                  IF ls_pdf-pdf_content IS INITIAL.
                    RAISE EXCEPTION TYPE zcx_cpi_post_error
                      EXPORTING
                        textid = zcx_cpi_post_error=>pdf_render_failed
                        mv_v1  = ls_pdf-error_text.
                  ENDIF.

                  " Convert xstring PDF to Base64 string for JSON transport
                  DATA(lv_pdf_base64) = cl_web_http_utility=>encode_x_base64( ls_pdf-pdf_content ).

                lo_json_builder->add_member( 'pdf' )->add_string( |{ lv_pdf_base64 }| ).

              ENDIF.
              lo_json_builder->end_object( ).
              lv_json_string = lo_json_builder->get_data( )->to_string( ).

              " --- Step 3: POST ---
              lo_request = lo_http_client->get_http_request( ).
              lo_request->set_content_type( 'application/json' ).
              lo_request->set_header_fields( VALUE #(
                  ( name = 'X-CSRF-Token' value = lv_csrf_token )
                  ( name = 'Cookie'       value = lv_session   ) ) ).
              lo_request->set_text( lv_json_string ).

              DATA(lo_post_response) = lo_http_client->execute( i_method = if_web_http_client=>post ).

              " --- Step 4: Validate HTTP status ---
              DATA(ls_status) = lo_post_response->get_status( ).

              IF ls_status-code NOT BETWEEN 200 AND 299.
*                RAISE EXCEPTION TYPE zcx_cpi_post_error
*                  EXPORTING
*                    textid = zcx_cpi_post_error=>http_post_failed
*                    mv_v1  = CONV #( ls_status-code )
*                    mv_v2  = ls_status-reason.
                    " Log error in custom table
*                    DATA(lv_uuid) = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
*                    DATA: ls_log TYPE ztb_cpi_post_log.
*                      ls_log-log_uuid       = lv_uuid.
*                      ls_log-company_code   = iv_company_code.
*                      ls_log-accounting_document = iv_accounting_document.
*                      ls_log-fiscal_year    = iv_fiscal_year.
*                      ls_log-status_code    = CONV #( ls_status-code ).
*                      ls_log-error_step     = 'HTTP POST'.
*                      ls_log-error_message     = ls_status-reason.
*
*                    INSERT INTO ztb_cpi_post_log VALUES @ls_log.
              ENDIF.

            CATCH cx_http_dest_provider_error cx_web_http_client_error.
                DATA(lv_status_code) = lo_post_response->get_status( ).

            CLEANUP.
              IF lo_http_client IS BOUND.
                TRY.
                    lo_http_client->close( ).
                  CATCH cx_web_http_client_error INTO DATA(lx_close).
                    " Ignore cleanup errors
                    DATA(lv_msg) = lx_close->get_text( ).
                ENDTRY.
              ENDIF.
          ENDTRY.


        ENDMETHOD.


  METHOD check_customer_type.

      SELECT SINGLE
          cc~country          AS company_country,
          cu~country          AS customer_country,
          cn~iseuropeanunionmember AS is_eu_member
        FROM i_companycode AS cc
        CROSS JOIN i_customer AS cu
        INNER JOIN i_country  AS cn ON cn~country = cu~country
        WHERE cc~companycode = @iv_company_code
          AND cu~customer    = @iv_customer
        INTO @DATA(ls_result).

      IF sy-subrc <> 0.
        rv_customer_type = 'not_found'.
      ENDIF.

      IF ls_result-company_country = ls_result-customer_country.
        rv_customer_type = 'local'.

      ELSEIF ls_result-is_eu_member = abap_true.
        rv_customer_type = 'intra_eu'.

      ELSE.
        rv_customer_type = 'foreign'.

      ENDIF.

  ENDMETHOD.



ENDCLASS.
