CLASS lhc_PrepaymentUpdates DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR PrepaymentUpdates RESULT result.

    METHODS testPrepayModification FOR MODIFY
      IMPORTING keys FOR ACTION PrepaymentUpdates~testPrepayModification RESULT result.

    METHODS updateDeliveryPrepayNum FOR MODIFY
      IMPORTING keys FOR ACTION PrepaymentUpdates~updateDeliveryPrepayNum RESULT result.

    METHODS postBillingPlan FOR MODIFY
      IMPORTING keys FOR ACTION PrepaymentUpdates~postBillingPlan RESULT result.
    METHODS reverseBillingPlan FOR MODIFY
      IMPORTING keys FOR ACTION PrepaymentUpdates~reverseBillingPlan RESULT result.
    METHODS convert_to_correct_amount
      IMPORTING iv_amount        TYPE zi_prepayment_delivery_so-DelvSoAmount
                iv_currency      TYPE waers
      RETURNING VALUE(rv_result) TYPE zi_prepayment_delivery_so-DelvSoAmount.

ENDCLASS.

CLASS lhc_PrepaymentUpdates IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD testPrepayModification.



  ENDMETHOD.

  METHOD convert_to_correct_amount.

    SELECT SINGLE FROM i_currency WITH PRIVILEGED ACCESS
        FIELDS decimals
        WHERE currency = @iv_currency
        INTO @DATA(lv_decimal).

    rv_result = SWITCH #( lv_decimal WHEN 0 THEN iv_amount * 100 ELSE iv_amount ).

  ENDMETHOD.

" UI Fixess
  METHOD updateDeliveryPrepayNum.

    DATA: lv_payload TYPE string.
    DATA: lt_Delivery_PrePay_SO TYPE STANDARD TABLE OF ztb_prepayment_c,
          lt_payload            TYPE STANDARD TABLE OF string,
          ls_payload            TYPE string,
          lv_changeset          TYPE string,
          lv_counter            TYPE i.
*    DATA: lt_update TYPE TABLE FOR READ IMPORT ZI_PREPAYMENT_DELIVERY_SO,
*          lt_final  TYPE TABLE FOR UPDATE ZI_PREPAYMENT_DELIVERY_SO.
    DATA: lt_update TYPE TABLE FOR UPDATE ZI_Prepayment_Updates,
          ls_update LIKE LINE OF lt_update.
    " Fetch the DeliverySO data that needs to be updated from Frontend
    SELECT
     ztb_prepayment_c~sap_uuid,
     ztb_prepayment_c~delvsosalesdocument,
     ztb_prepayment_c~delvsosalesdocumentitem,
     ztb_prepayment_c~prepaymentrequestd,
     ztb_prepayment_c~prepaymentrequestp,
     ztb_prepayment_c~changedatetime,
     ztb_prepayment_c~prepaymentso,
     ztb_prepayment_c~prepaymentsoitem,
     ztb_prepayment_c~lastchangedby,
     ztb_prepayment_c~status
    FROM
    ztb_prepayment_c
      WHERE Status = 'NEW'
      INTO CORRESPONDING FIELDS OF TABLE @lt_Delivery_PrePay_SO.


    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                                     comm_scenario  = 'ZCS_PREPAYMENT_CONSUMPTION'
                                                     service_id     = 'ZOS_SALES_ORDER_V4_REST' ).

        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( i_destination = lo_destination ).

        DATA(lo_request) = lo_http_client->get_http_request( ).

        lo_http_client->accept_cookies( abap_true ).

        lo_request->set_uri_path( |/$batch| ).

        lo_request->set_content_type( 'multipart/mixed; boundary=batch_ODV4' ).

        lo_request->set_header_fields( VALUE #( ( name  = 'X-CSRF-Token'
                                                  value = 'fetch' ) ) ).

        DATA(lo_response) = lo_http_client->execute( i_method = if_web_http_client=>get ).

        DATA(lv_csrf_token) = lo_response->get_header_field( 'X-CSRF-Token' ).

        DATA(lv_session) = lo_response->get_header_field( 'set-cookie' ).

        " TODO: Generate the RAW TEXT for the POST request
        TYPES: BEGIN OF ty_order_map,
             content_id  TYPE i,
             sales_order TYPE string,
           END OF ty_order_map.

        DATA lt_order_map TYPE STANDARD TABLE OF ty_order_map.
        "DATA(lv_json_string) = "123".
        "DATA(lv_changeset) = 'changeset_odv4'.
        lv_counter = 1.
        LOOP AT lt_Delivery_PrePay_SO ASSIGNING FIELD-SYMBOL(<fs_deliveryso>).

          lv_changeset = |changeset_odv4_{ lv_counter }|.

          " ← Track the mapping of counter → sales order
          APPEND VALUE #(
            content_id  = lv_counter
            sales_order = <fs_deliveryso>-delvsosalesdocument
          ) TO lt_order_map.

          " Batch wrapper for each changeset
          APPEND '--batch_ODV4' TO lt_payload.
          APPEND |Content-Type: multipart/mixed; boundary={ lv_changeset }| TO lt_payload.
          APPEND '' TO lt_payload.

          " Start changeset
          APPEND |--{ lv_changeset }| TO lt_payload.
          APPEND 'Content-Type: application/http' TO lt_payload.
          APPEND 'Content-Transfer-Encoding: binary' TO lt_payload.
          APPEND |Content-ID: { lv_counter }| TO lt_payload.
          APPEND '' TO lt_payload.

          " PATCH request
          APPEND |PATCH SalesOrderItem(SalesOrder='{ <fs_deliveryso>-delvsosalesdocument }',SalesOrderItem='{ <fs_deliveryso>-delvsosalesdocumentitem }') HTTP/1.1| TO lt_payload.
          APPEND 'Content-Type: application/json' TO lt_payload.
          APPEND 'If-Match: *' TO lt_payload.
          APPEND '' TO lt_payload.
          APPEND '{' TO lt_payload.
          APPEND |  "YY1_PrepaymentReqNum_SDI": "{ <fs_deliveryso>-prepaymentrequestd }"| TO lt_payload.
          APPEND '}' TO lt_payload.

          " End changeset
          APPEND |--{ lv_changeset }--| TO lt_payload.

          lv_counter += 1.
        ENDLOOP.

        " Close batch
        APPEND '--batch_ODV4--' TO lt_payload.


        LOOP AT lt_payload INTO ls_payload.
          IF sy-tabix = 1.
            lv_payload = ls_payload.
          ELSE.
            CONCATENATE lv_payload ls_payload
              INTO lv_payload
              SEPARATED BY cl_abap_char_utilities=>cr_lf.
            CLEAR ls_payload.
          ENDIF.
        ENDLOOP.


        lo_request->set_header_fields( VALUE #( ( name  = 'X-CSRF-Token'
                                                  value = lv_csrf_token ) ) ).

        lo_request->set_header_fields( VALUE #( ( name  = 'Accept'
                                                  value = 'multipart/mixed' ) ) ).

        lo_request->set_form_field( i_name  = 'Cookie'
                                    i_value = lv_session ) .

        "hardcoded for testing purposes
        lo_request->set_text( lv_payload ).

        DATA(lo_post_response) = lo_http_client->execute( i_method = if_web_http_client=>post ).

        " Need to update to check if response is successful then only update the status
        DATA(lt_headers) = lo_post_response->get_header_fields( ).
        DATA(lv_response_text) = lo_post_response->get_text( ).

        TYPES: BEGIN OF ty_result,
                 content_id    TYPE i,
                 http_code   TYPE string,
                 sales_order TYPE string,
                 error_message TYPE string,
               END OF ty_result.

        DATA: lt_result2 TYPE STANDARD TABLE OF ty_result,
              ls_result  TYPE ty_result.

        DATA:
          lv_content_type   TYPE string,
          lv_outer_boundary TYPE string,
          lv_inner_boundary TYPE string,
          lt_outer_parts    TYPE STANDARD TABLE OF string,
          lt_inner_parts    TYPE STANDARD TABLE OF string,
          lv_http_code      TYPE string,
          lv_salesorder     TYPE string.

        " 1. Get boundary from Content-Type
        lv_content_type = lo_post_response->get_header_field( i_name = 'Content-Type' ).

        FIND REGEX 'boundary=([A-Za-z0-9-]+)' IN lv_content_type
             SUBMATCHES lv_outer_boundary.

        DATA(crlf) = cl_abap_char_utilities=>cr_lf.

        "--- Step 1: split by outer boundary
        SPLIT lv_response_text AT '--' && lv_outer_boundary INTO TABLE lt_outer_parts.

        DELETE lt_outer_parts WHERE table_line IS INITIAL
                               OR table_line = '--' && crlf.  "remove closing

        "--- Step 2: loop outer parts
        LOOP AT lt_outer_parts INTO DATA(lv_outer_part).

          " 1) Extract HTTP code from headers
          CLEAR lv_http_code.
          FIND REGEX 'HTTP/1\.1\s+(\d+)' IN lv_outer_part SUBMATCHES lv_http_code.

          " 2) Extract SalesOrder from JSON body
          CLEAR lv_salesorder.
          FIND REGEX '"SalesOrder":"([^"]+)"' IN lv_outer_part SUBMATCHES lv_salesorder.

          IF lv_salesorder IS INITIAL.
              " Extract Content-ID from response part
              DATA: lv_content_id TYPE i.
              DATA: lv_content_id_str TYPE string.
              CLEAR lv_content_id_str.
              FIND REGEX 'content-id:\s*(\d+)' IN lv_outer_part SUBMATCHES lv_content_id_str.
              lv_content_id = lv_content_id_str.

              " Look up sales order from map using content-id
              CLEAR lv_salesorder.
              lv_salesorder = VALUE #( lt_order_map[ content_id = lv_content_id ]-sales_order OPTIONAL ).
          ENDIF.

          " Extract error message from JSON body (if present)
          DATA: lv_error_msg TYPE string.
          CLEAR lv_error_msg.
          FIND REGEX '"message":"([^"]+)"' IN lv_outer_part SUBMATCHES lv_error_msg.

          " 3) Store into result table
          CLEAR ls_result.
          ls_result-http_code   = lv_http_code.
          ls_result-sales_order = lv_salesorder.
          ls_result-error_message = COND #(
            WHEN lv_error_msg IS NOT INITIAL
            THEN |{ lv_http_code } : { lv_error_msg }|
            ELSE |{ lv_http_code } : No message returned|
          ).
          APPEND ls_result TO lt_result2.

        ENDLOOP.

        READ ENTITIES OF ZI_Prepayment_Updates IN LOCAL MODE
        ENTITY PrepaymentUpdates
        ALL FIELDS
        WITH CORRESPONDING #( lt_Delivery_PrePay_SO )
        RESULT DATA(lt_result).

*        LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<fs_delv_result>).
*
*          IF line_exists( lt_result2[ sales_order = <fs_delv_result>-delvsosalesdocument
*                                       http_code = '200' ] ).
*            <fs_delv_result>-Status        = 'MODIFIED'.
*          ELSE.
*            <fs_delv_result>-Status        = 'ERROR'.
*          ENDIF.
*
*
*          MODIFY ENTITIES OF ZI_Prepayment_Updates IN LOCAL MODE
*          ENTITY PrepaymentUpdates
*          UPDATE FIELDS ( Status )
*          WITH CORRESPONDING #( lt_result ).
*        ENDLOOP.

        LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<fs_delv_result>).

          DATA(ls_api_result) = VALUE ty_result(
            lt_result2[ sales_order = <fs_delv_result>-delvsosalesdocument ] OPTIONAL ).

          IF ls_api_result-http_code = '200'.
            <fs_delv_result>-Status       = 'MODIFIED'.
            <fs_delv_result>-Message = ''.
          ELSE.
            <fs_delv_result>-Status       = 'ERROR'.
            <fs_delv_result>-Message = ls_api_result-error_message.
          ENDIF.

        ENDLOOP.

        " Single MODIFY outside the loop
        MODIFY ENTITIES OF ZI_Prepayment_Updates IN LOCAL MODE
          ENTITY PrepaymentUpdates
          UPDATE FIELDS ( Status Message )
          WITH CORRESPONDING #( lt_result ).


        "CATCH cx_http_dest_provider_error cx_web_http_client_error.
        " Handle the response from the API
      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lo_http_error).##NO_HANDLER

        " TODO: Add proper exception handling
        DATA(lv_status_code) = lo_post_response->get_status( ).

        " Get Response Payload from API
*                DATA(lv_status_code) = lo_post_response->get_status( ).
*

*
*                DATA(lv_content) = lo_post_response->get_content_type( ).
*
*                DATA(lv_header_fields) = lo_post_response->get_header_fields( ).


    ENDTRY.
    DATA(lv_response) = lo_post_response->get_text( ).

  ENDMETHOD.


  METHOD postbillingplan.

    DATA so_number TYPE string.
    DATA so_item TYPE string.
    DATA lv_consumption_amt TYPE p DECIMALS 2.
    DATA lv_currency TYPE c LENGTH 3.
    DATA lv_scenario TYPE c LENGTH 2.
    DATA lv_delv_remaining_amt TYPE p DECIMALS 2.
    DATA lv_prepay_remaining_amt TYPE p DECIMALS 2.
    DATA lv_prepay_so TYPE string.
    DATA lv_prepay_so_item TYPE string.
    DATA lv_prepay_req_num TYPE string.
    DATA lv_io_type TYPE c LENGTH 1.
    "Params
    LOOP AT keys INTO DATA(ls_key).
      so_number = ls_key-delvSoSalesDocument.
      so_item = ls_key-delvSoSalesDocumentItem.
      lv_consumption_amt = ls_key-%param-param_amount_to_apply.
      lv_currency = ls_key-%param-param_currency.
      lv_delv_remaining_amt = ls_key-%param-param_delv_remaining_amount.
      lv_prepay_remaining_amt = ls_key-%param-param_prepay_remaining_amount.
      lv_scenario = ls_key-%param-param_scenario.
      lv_prepay_so = ls_key-%param-param_prepay_so.
      lv_prepay_so_item = ls_key-%param-param_prepay_so_item.
      lv_prepay_req_num = ls_key-%param-param_prepay_req_num.
      lv_io_type = ls_key-%param-param_io_type.
    ENDLOOP.

    DATA(lv_log_id) = zcl_prepay_log=>start_process(
      iv_flow_type          = 'BILLPLAN'
      iv_delivery_so        = so_number
      iv_delivery_so_item   = so_item
      iv_prepayment_so      = lv_prepay_so
      iv_prepayment_so_item = lv_prepay_so_item ).
    DATA lv_step_seq TYPE i VALUE 0.

    DATA lv_status     TYPE i.

    DATA lv_csrf_token TYPE string.
    DATA lv_session    TYPE string.
    DATA http_status    TYPE string.
    DATA rv_result    TYPE string.
    DATA lo_request_body TYPE string.
    DATA lv_response_body TYPE string.
    DATA lo_response TYPE REF TO if_web_http_response.
    DATA lo_request TYPE REF TO if_web_http_request.

    DATA lv_billing_plan TYPE string.
    DATA lv_billing_plan_item TYPE i.
    DATA lv_so_net_amt TYPE p DECIMALS 2.
    DATA lv_so_currency TYPE c LENGTH 3.


    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_datenow)   = |{ lv_today+0(4) }-{ lv_today+4(2) }-{ lv_today+6(2) }T00:00:00|.

    DATA lv_difference_amt TYPE p DECIMALS 2.

    IF lv_scenario = 'A' OR lv_scenario = 'D1' or lv_scenario = 'D2'.
        "Get Prepayment Net Amount
*        SELECT PrepaymentNetAmount, PrepaymentCurrency
*        FROM zi_prepayment_delivery_so_key
*        WHERE prepaymentso = @lv_prepay_so
*        AND DelvSoSalesDocument = @so_number
*        AND DelvSoSalesDocumentItem = @so_item
*        INTO @DATA(lv_prepay_net_temp).
*        ENDSELECT.

        SELECT SINGLE netamount, transactioncurrency
        FROM i_salesorderitem
        WHERE salesorder = @lv_prepay_so
        AND salesorderitem = @lv_prepay_so_item
        INTO @DATA(lv_prepay_net_temp).

        DATA lv_amount_big TYPE p LENGTH 12 DECIMALS 2.

        lv_amount_big = lv_prepay_net_temp-netamount.
        DATA(lv_prepay_net)  = convert_to_correct_amount(
                                  iv_amount   = lv_amount_big
                                  iv_currency = lv_prepay_net_temp-transactioncurrency ).

        " Check if prepayment is consumed previously and get the amount consumed
        DATA lv_item TYPE posnr.
        lv_item = lv_prepay_so_item.   "Automatically pads to 000010

        "Check consumption history for classic IO type only
        IF lv_io_type <> 'O'.
            SELECT prepaymentreqnumber, salesorder, salesorderitem, soamount
            FROM zi_consumption_history
            WHERE salesorder = @lv_prepay_so
            AND salesorderitem = @lv_item
            AND prepaymentreqnumber = @lv_prepay_req_num
            INTO TABLE @DATA(lt_prepay_consumed_amt).

            "If prepayment is used previously
            IF sy-subrc = 0.
                  DATA(lv_total_amt) = 0.

                  LOOP AT lt_prepay_consumed_amt INTO DATA(ls_item2).
                    lv_total_amt = lv_total_amt + ls_item2-soamount.
                  ENDLOOP.
                  "Prepayment Remaining Amount is Prepay Net Amt - Total Consumed
                  lv_prepay_remaining_amt = lv_prepay_net - lv_total_amt.

                  lv_step_seq = lv_step_seq + 1.
                zcl_prepay_log=>log_step(
                  iv_correlation_id = lv_log_id
                  iv_flow_type      = 'BILLPLAN'
                  iv_step_seq       = lv_step_seq
                  iv_step_name      = 'PREPAY_REMAINING_AMT'
                  iv_is_error       = xsdbool( lv_prepay_remaining_amt IS INITIAL )
                  iv_response_body  = |Prepay Remaining Amt: { lv_prepay_remaining_amt }| ).

            ENDIF.
         ENDIF.
    ENDIF.

    lv_difference_amt = lv_delv_remaining_amt - lv_prepay_remaining_amt.

    "Scenario A
    DATA lv_threshold_amt TYPE p LENGTH 16 DECIMALS 2.


    TYPES: BEGIN OF ty_result,
             billingplannum  TYPE string,
             billingplanitem TYPE string,
           END OF ty_result.

    TRY.

        "--- HTTP CLIENT ---
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario  = 'ZCS_PREPAYMENT_CONSUMPTION'
                             service_id     = 'ZOS_SALES_ORDER_V2_REST' ).

        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination(
                         i_destination = lo_destination ).

        "--- STEP 1.1: Fetch billing plan & CSRF token ---

        lo_http_client->accept_cookies( abap_true ).
        lo_request = lo_http_client->get_http_request( ).

        lo_request->set_uri_path( |/A_SalesOrderItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }')/to_BillingPlan| ).
        lo_request->set_header_fields( VALUE #(
          ( name = 'X-CSRF-Token' value = 'fetch' )
          ( name = 'Accept'       value = 'application/xml' )
        ) ).

        lo_response = lo_http_client->execute( i_method = if_web_http_client=>get ).

        "--- Collect Cookies ----
        DATA(lt_response_headers) = lo_response->get_header_fields(  ).

        http_status = lv_status = lo_response->get_header_field( '~status_code' ).
        lv_csrf_token = lo_response->get_header_field( 'X-CSRF-Token' ).
        LOOP AT lt_response_headers INTO DATA(ls_header) WHERE name = 'set-cookie'.
          DATA(lv_cookie) = ls_header-value.
          " Take only name=value before first semicolon
          SPLIT lv_cookie AT ';' INTO lv_cookie DATA(dummy).
          IF lv_session IS INITIAL.
            lv_session = lv_cookie.
          ELSE.
            CONCATENATE lv_session '; ' lv_cookie INTO lv_session.
          ENDIF.
        ENDLOOP.
*        lv_session   = lo_response->get_header_field( 'set-cookie' ).

        lv_step_seq = lv_step_seq + 1.
        zcl_prepay_log=>log_step(
          iv_correlation_id = lv_log_id
          iv_flow_type      = 'BILLPLAN'
          iv_step_seq       = lv_step_seq
          iv_step_name      = 'GET_BILLING_PLAN'
          iv_http_method    = 'GET'
          iv_http_status    = http_status
          iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
          iv_response_body  = lo_response->get_text( ) ).

        IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
          zcl_prepay_log=>finish_process(
            iv_log_id       = lv_log_id
            iv_status       = 'E'
            iv_message_text = |Step GET_BILLING_PLAN failed with HTTP { http_status }| ).

          APPEND VALUE #(
              %tky = ls_key-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Billing plan posting failed at step GET_BILLING_PLAN (HTTP { http_status }). Ref: { lv_log_id }|
                     )
            ) TO reported-prepaymentupdates.

          RETURN.
        ENDIF.

        "--------- Parse Response-------------
        lv_response_body = lo_response->get_text(  ).
        IF lo_response->get_status( )-code = '200' AND lv_response_body IS NOT INITIAL.
          lv_billing_plan = substring_before( val = substring_after( val = lv_response_body
                                                                                     sub = |<d:BillingPlan>| )
                                                              sub = |</d:BillingPlan>| ).

        ENDIF.

        "--------- End Parse Response---------
        "--------------- GET CONFIG VALUE ----------------------
        IF lv_scenario EQ 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2'.


            SELECT SINGLE salesorganization
            FROM I_SALESDOCUMENT
            WHERE SALESDOCUMENT = @so_number
            INTO @DATA(lv_salesorg).


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

           lv_threshold_amt = VALUE #( lt_rounding[ value1 = lv_salesorg ]-value2 OPTIONAL ).

           lv_step_seq = lv_step_seq + 1.
            zcl_prepay_log=>log_step(
              iv_correlation_id = lv_log_id
              iv_flow_type      = 'BILLPLAN'
              iv_step_seq       = lv_step_seq
              iv_step_name      = 'LOOKUP_ROUNDING_THRESHOLD'
              iv_is_error       = xsdbool( lv_threshold_amt IS INITIAL )
              iv_response_body  = |Sales org { lv_salesorg }: threshold { lv_threshold_amt }| ).
        ENDIF.
        "--------------- GET CONFIG VALUE ----------------------
        "--- STEP 1.2: Get Net Amount of Delivery SO ---

        DATA lt_items TYPE TABLE OF zi_delivery_so_item.

        SELECT SalesDocument,
            SalesDocumentItem,
            PrepaymentReqNumDelivery,
            SalesDocumentItemCategory,
            YY1_SFSOIOType_SDI,
            TransactionCurrency,
            DeliveryMonth,
            NetAmount,
            GrossAmount,
            BillingDocument,
            BillingDocumentItem
        FROM zi_delivery_so_item
        WHERE salesdocument     = @so_number
        AND salesdocumentitem = @so_item
        INTO TABLE @lt_items.

        IF sy-subrc = 0.
          LOOP AT lt_items INTO DATA(ls_so_item).
            "lv_so_net_amt = ls_so_item-GrossAmount.
            DATA lv_so_net_amt_big TYPE p LENGTH 12 DECIMALS 2.
            lv_so_net_amt_big = ls_so_item-NetAmount.
            lv_so_net_amt = convert_to_correct_amount(
                                  iv_amount   = lv_so_net_amt_big
                                  iv_currency = ls_so_item-TransactionCurrency ).
            lv_so_currency = ls_so_item-TransactionCurrency.
          ENDLOOP.
        ENDIF.


        "--------- End Parse Response---------
         "--------- Check Currency ---------
        IF lv_so_currency NE lv_currency.
          lv_step_seq = lv_step_seq + 1.
          zcl_prepay_log=>log_step(
            iv_correlation_id = lv_log_id
            iv_flow_type      = 'BILLPLAN'
            iv_step_seq       = lv_step_seq
            iv_step_name      = 'CHECK_CURRENCY'
            iv_is_error       = abap_true
            iv_response_body  = |SO currency { lv_so_currency } does not match requested currency { lv_currency }| ).

          zcl_prepay_log=>finish_process(
            iv_log_id       = lv_log_id
            iv_status       = 'E'
            iv_message_text = |Currency mismatch: SO is { lv_so_currency }, requested { lv_currency }| ).

          APPEND VALUE #(
              %tky = ls_key-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Currency mismatch: SO is { lv_so_currency }, requested { lv_currency } (ref: { lv_log_id })|
                     )
            ) TO reported-prepaymentupdates.

          RETURN.
        ENDIF.
        "--------- End Check Currency ---------

        "--------- IF NO BILLING PLAN ---------

        IF lv_billing_plan IS INITIAL.

              "--- STEP 2: Update SO Item Category ---
              lo_request->set_uri_path(
            |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }')| ).

              lo_request->set_header_fields( VALUE #(
                ( name = 'X-CSRF-Token' value = lv_csrf_token )
                ( name = 'Accept'       value = 'application/json' )
                ( name = 'Content-Type' value = 'application/json' )
                ( name = 'Cookie'       value = lv_session )
              ) ).

              "Create payload for PATCH d
              DATA(lo_json_builder_step2) = xco_cp_json=>data->builder( ).

              lo_json_builder_step2->begin_object( ).
              lo_json_builder_step2->add_member( 'SalesOrderItemCategory' )->add_string( 'CTAD' ).
              lo_json_builder_step2->add_member( 'BillingPlan' )->add_string( '' ).

              IF lv_scenario EQ 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2'.
                IF lv_delv_remaining_amt <= lv_prepay_remaining_amt.
                    lo_json_builder_step2->add_member( 'CustomerGroup' )->add_string( '07' ).
                ELSE.
                    "check difference
                    IF lv_difference_amt < lv_threshold_amt.
                        lo_json_builder_step2->add_member( 'CustomerGroup' )->add_string( '07' ).
                    ENDIF.
                ENDIF.
              ENDIF.
              lo_json_builder_step2->end_object( ).

              lo_request_body = lo_json_builder_step2->get_data( )->to_string( ).
              lo_request->set_text( lo_request_body ).



              lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


              http_status = lv_status = lo_response->get_header_field( '~status_code' ).

              lv_step_seq = lv_step_seq + 1.
            zcl_prepay_log=>log_step(
              iv_correlation_id = lv_log_id
              iv_flow_type      = 'BILLPLAN'
              iv_step_seq       = lv_step_seq
              iv_step_name      = 'UPDATE_ITEM_CATEGORY'
              iv_http_method    = 'PATCH'
              iv_http_status    = http_status
              iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
              iv_response_body  = lo_response->get_text( ) ).

            IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
              zcl_prepay_log=>finish_process(
                iv_log_id       = lv_log_id
                iv_status       = 'E'
                iv_message_text = |Step UPDATE_ITEM_CATEGORY failed with HTTP { http_status }| ).

              APPEND VALUE #(
                  %tky = ls_key-%tky
                  %msg = new_message_with_text(
                           severity = if_abap_behv_message=>severity-error
                           text     = |Billing plan posting failed at step UPDATE_ITEM_CATEGORY (HTTP { http_status }). Ref: { lv_log_id }|
                         )
                ) TO reported-prepaymentupdates.

              RETURN.
            ENDIF.

              "--- STEP 3: Create Empty Billing Plan ---

              lo_request = lo_http_client->get_http_request( ).
              lo_request->set_uri_path( '/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItemBillingPlan' ).

              "Set CSRF + Cookie headers
              lo_request->set_header_fields( VALUE #(
                ( name = 'X-CSRF-Token' value = lv_csrf_token )
                ( name = 'Accept'       value = 'application/json' )
                ( name = 'Content-Type' value = 'application/json' )
                ( name = 'Cookie'       value = lv_session )
              ) ).

              "Create payload for POST
              DATA(lo_json_builder_step3) = xco_cp_json=>data->builder( ).

              lo_json_builder_step3->begin_object( ).
              lo_json_builder_step3->add_member( 'SalesOrder' )->add_string( so_number ).
              lo_json_builder_step3->add_member( 'SalesOrderItem' )->add_string( |{ so_item }| ).
              lo_json_builder_step3->add_member( 'BillingPlan' )->add_string( '' ).
              lo_json_builder_step3->add_member( 'BillingPlanIsInHeader' )->add_boolean( abap_false ).
              lo_json_builder_step3->end_object( ).

              lo_request_body = lo_json_builder_step3->get_data( )->to_string( ).
              lo_request->set_text( lo_request_body ).


              lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).


              http_status = lv_status = lo_response->get_header_field( '~status_code' ).

              lv_step_seq = lv_step_seq + 1.
                zcl_prepay_log=>log_step(
                  iv_correlation_id = lv_log_id
                  iv_flow_type      = 'BILLPLAN'
                  iv_step_seq       = lv_step_seq
                  iv_step_name      = 'CREATE_BILLING_PLAN'
                  iv_http_method    = 'POST'
                  iv_http_status    = http_status
                  iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                  iv_response_body  = lo_response->get_text( ) ).

                IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                  zcl_prepay_log=>finish_process(
                    iv_log_id       = lv_log_id
                    iv_status       = 'E'
                    iv_message_text = |Step CREATE_BILLING_PLAN failed with HTTP { http_status }| ).

                  APPEND VALUE #(
                      %tky = ls_key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Billing plan posting failed at step CREATE_BILLING_PLAN (HTTP { http_status }). Ref: { lv_log_id }|
                             )
                    ) TO reported-prepaymentupdates.

                  RETURN.
                ENDIF.

              "--- STEP 4: Fetch billing plan number of new billing plan ---


              SELECT SINGLE BillingPlan
              FROM i_salesdocumentitem
              WHERE salesdocument     = @so_number
              AND salesdocumentitem = @so_item
              INTO @DATA(ls_billingplan).

              IF sy-subrc = 0.
                lv_billing_plan = |{ CONV i( ls_billingplan ) }|.
              ENDIF.

              "--------- End Parse Response---------

              " -------------- Add IsprepaymentDelveryForm flag-----------------
               lo_request->set_uri_path(
            |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }')| ).

              lo_request->set_header_fields( VALUE #(
                ( name = 'X-CSRF-Token' value = lv_csrf_token )
                ( name = 'Accept'       value = 'application/json' )
                ( name = 'Content-Type' value = 'application/json' )
                ( name = 'Cookie'       value = lv_session )
                 ( name = 'If-Match'     value = '*' )
              ) ).

              "Create payload for PATCH d
              DATA(lo_json_builder_flag) = xco_cp_json=>data->builder( ).

              lo_json_builder_flag->begin_object( ).

              IF lv_scenario EQ 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2'.
                    lo_json_builder_flag->add_member( 'YY1_ISPREPAYDELVFORM_SDI' )->add_string( 'Y' ).
              ELSE.
                    lo_json_builder_flag->add_member( 'YY1_ISPREPAYDELVFORM_SDI' )->add_string( 'N' ).
              ENDIF.
              lo_json_builder_flag->end_object( ).

              lo_request_body = lo_json_builder_flag->get_data( )->to_string( ).
              lo_request->set_text( lo_request_body ).

              lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).
              http_status = lv_status = lo_response->get_header_field( '~status_code' ).

              lv_step_seq = lv_step_seq + 1.
                zcl_prepay_log=>log_step(
                  iv_correlation_id = lv_log_id
                  iv_flow_type      = 'BILLPLAN'
                  iv_step_seq       = lv_step_seq
                  iv_step_name      = 'UPDATE_PREPAY_DELV_FLAG'
                  iv_http_method    = 'PATCH'
                  iv_http_status    = http_status
                  iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                  iv_response_body  = lo_response->get_text( ) ).

                IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                  zcl_prepay_log=>finish_process(
                    iv_log_id       = lv_log_id
                    iv_status       = 'E'
                    iv_message_text = |Step UPDATE_PREPAY_DELV_FLAG failed with HTTP { http_status }| ).

                  APPEND VALUE #(
                      %tky = ls_key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Billing plan posting failed at step UPDATE_PREPAY_DELV_FLAG (HTTP { http_status }). Ref: { lv_log_id }|
                             )
                    ) TO reported-prepaymentupdates.

                  RETURN.
                ENDIF.

              lo_request->delete_header_field( 'If-Match' ).

               " -------------- END Add IsprepaymentDelveryForm flag-----------------
        ELSE.
            " Update customer group for Delivery SO for Scenario A
            IF ( lv_scenario EQ 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2' ) AND ( lv_difference_amt < lv_threshold_amt OR lv_difference_amt <= 0 ).
                SELECT SINGLE CUSTOMERGROUP
                FROM I_SALESDOCUMENTITEM
                WHERE salesdocument     = @so_number
                AND salesdocumentitem = @so_item
                INTO @DATA(lv_customergrp).

                IF sy-subrc = 0 AND lv_customergrp IS INITIAL.
                    " Add customer group

                  lo_request = lo_http_client->get_http_request( ).
                  lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }')| ).

                  "Set CSRF + Cookie headers
                  lo_request->set_header_fields( VALUE #(
                    ( name = 'X-CSRF-Token' value = lv_csrf_token )
                    ( name = 'Accept'       value = 'application/json' )
                    ( name = 'Content-Type' value = 'application/json' )
                    ( name = 'Cookie'       value = lv_session )
                  ) ).

                  "Create payload for POST
                  DATA(lo_json_builder_11) = xco_cp_json=>data->builder( ).

                  lo_json_builder_11->begin_object( ).
                  lo_json_builder_11->add_member( 'CustomerGroup' )->add_string( '07' ).
                  lo_json_builder_11->end_object( ).

                  lo_request_body = lo_json_builder_11->get_data( )->to_string( ).
                  lo_request->set_text( lo_request_body ).


                  lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


                  http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                  lv_step_seq = lv_step_seq + 1.
                zcl_prepay_log=>log_step(
                  iv_correlation_id = lv_log_id
                  iv_flow_type      = 'BILLPLAN'
                  iv_step_seq       = lv_step_seq
                  iv_step_name      = 'UPDATE_CUSTOMER_GROUP'
                  iv_http_method    = 'PATCH'
                  iv_http_status    = http_status
                  iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                  iv_response_body  = lo_response->get_text( ) ).

                IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                  zcl_prepay_log=>finish_process(
                    iv_log_id       = lv_log_id
                    iv_status       = 'E'
                    iv_message_text = |Step UPDATE_CUSTOMER_GROUP failed with HTTP { http_status }| ).

                  APPEND VALUE #(
                      %tky = ls_key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Billing plan posting failed at step UPDATE_CUSTOMER_GROUP (HTTP { http_status }). Ref: { lv_log_id }|
                             )
                    ) TO reported-prepaymentupdates.

                  RETURN.
                ENDIF.

                ENDIF.

            ENDIF.

        ENDIF.

        "--------- END IF NO BILLING PLAN---------

        "--- STEP 5: Get Billing Plan items ---

        TYPES: BEGIN OF ty_billingplanitem,
                 BillingPlan        TYPE string,
                 BillingPlanItem    TYPE string,
                 BillingPlanAmount  TYPE string,
                 BillingBlockReason TYPE string,
               END OF ty_billingplanitem.

        TYPES: tt_billingplanitems TYPE STANDARD TABLE OF ty_billingplanitem WITH DEFAULT KEY.

        TYPES: BEGIN OF ty_d,
                 results TYPE tt_billingplanitems,
               END OF ty_d.

        TYPES: BEGIN OF ty_wrapper,
                 d TYPE ty_d,
               END OF ty_wrapper.


        DATA: lv_json        TYPE string,
              ls_wrapper     TYPE ty_wrapper,
              lt_billingplan TYPE tt_billingplanitems.

        lo_http_client->accept_cookies( abap_true ).
        lo_request = lo_http_client->get_http_request( ).

        lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItemBillingPlan(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }',BillingPlan='{ lv_billing_plan }')/to_BillingPlanItem| ).
        lo_request->set_header_fields( VALUE #(
          ( name = 'X-CSRF-Token' value = 'fetch' )
          ( name = 'Accept'       value = 'application/json' )
        ) ).

        lo_response = lo_http_client->execute( i_method = if_web_http_client=>get ).
        http_status = lv_status = lo_response->get_header_field( '~status_code' ).


        "Debug
        DATA(lv_body_debug5)   = lo_request->get_text( ).
        DATA(lt_headers_debug5) = lo_request->get_header_fields( ).
        DATA(lv_method_debug5) = lo_request->get_method( ).
        DATA(lv_res_debug5) = lo_response->get_text( ).
        DATA(lt_res_headers5) = lo_response->get_header_fields( ).
        DATA(lv_path_debug5) = lo_request->get_header_field( i_name = '~request_uri' ).

        "end debug

        "--------- Parse Response-------------
        lv_json = lo_response->get_text( ).
        /ui2/cl_json=>deserialize(
                      EXPORTING
                        json        = lv_json
                        pretty_name = /ui2/cl_json=>pretty_mode-none
                      CHANGING
                        data        = ls_wrapper ).
        lt_billingplan = ls_wrapper-d-results.

        "--------- End Parse Response---------

        "--------- Calculate billing item total-------------
        DATA: lv_billing_plan_consumed_total TYPE p DECIMALS 2 VALUE 0. "total amount consumed

        LOOP AT lt_billingplan INTO DATA(ls_plan).
          IF ls_plan-billingblockreason IS NOT INITIAL.
            " convert string to decimal before summing
            lv_billing_plan_consumed_total = lv_billing_plan_consumed_total + ls_plan-BillingPlanAmount.
          ENDIF.

        ENDLOOP.
        "--------- End Calculate billing item total---------

        "--------- Calculate billing item total for billing plan with billing block Y4 (Scenario A) -------------
        DATA: lv_amount_applied_A TYPE p DECIMALS 2 VALUE 0. "total amount consumed
        IF lv_scenario = 'A' or lv_scenario = 'D1' or lv_scenario = 'D2'.
            LOOP AT lt_billingplan INTO DATA(ls_plan_A).
              IF ls_plan_A-billingblockreason EQ 'Y4'.
                " sum previous Y4 items
                lv_amount_applied_A = lv_amount_applied_A + ls_plan_A-BillingPlanAmount.
              ENDIF.
            ENDLOOP.
        ENDIF.

        " Add amount to be applied
        lv_amount_applied_A = lv_amount_applied_A + lv_consumption_amt.
        "--------- End Calculate billing item total for billing plan with billing block Y4 (Scenario A) ---------

        "--------- Get Line with Remaining amount -------------
        DATA lv_remainder_line_item TYPE string.

        LOOP AT lt_billingplan INTO DATA(ls_item).
          IF ls_item-billingblockreason IS INITIAL.
            lv_remainder_line_item = ls_item-billingplanitem.
            EXIT. " stop after the first match
          ENDIF.
        ENDLOOP.

        "--------- End Get Line with Remaining amount ---------
        "--------- Calculate New Remaining amount -------------

        DATA lv_remainder_amt TYPE p DECIMALS 2.

        lv_remainder_amt = lv_so_net_amt - ( lv_consumption_amt + lv_billing_plan_consumed_total ).

        IF lv_remainder_amt < 0.
          lv_step_seq = lv_step_seq + 1.
          zcl_prepay_log=>log_step(
            iv_correlation_id = lv_log_id
            iv_flow_type      = 'BILLPLAN'
            iv_step_seq       = lv_step_seq
            iv_step_name      = 'CHECK_REMAINDER_AMOUNT'
            iv_is_error       = abap_true
            iv_response_body  = |Remainder amount { lv_remainder_amt } is negative — amount to apply exceeds remaining amount| ).

          zcl_prepay_log=>finish_process(
            iv_log_id       = lv_log_id
            iv_status       = 'E'
            iv_message_text = 'Amount to apply bigger than remaining amount' ).

          APPEND VALUE #(
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Amount to apply bigger than remaining amount (ref: { lv_log_id })|
                     )
            ) TO reported-prepaymentupdates.

          RETURN.
        ENDIF.


        "--------- End Calculate New Remaining amount ---------

        "--- STEP 5: Add Billing Plan line (Consumption Line) ---

        lo_request = lo_http_client->get_http_request( ).
        lo_request->set_uri_path( '/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem' ).

        "Set CSRF + Cookie headers
        lo_request->set_header_fields( VALUE #(
          ( name = 'X-CSRF-Token' value = lv_csrf_token )
          ( name = 'Accept'       value = 'application/xml' )
          ( name = 'Content-Type' value = 'application/json' )
          ( name = 'Cookie'       value = lv_session )
        ) ).

        "Create payload for POST
        DATA(lo_json_builder_step5) = xco_cp_json=>data->builder( ).

        lo_json_builder_step5->begin_object( ).
        lo_json_builder_step5->add_member( 'SalesOrder' )->add_string( so_number ).
        lo_json_builder_step5->add_member( 'SalesOrderItem' )->add_string( |{ so_item }| ).
        lo_json_builder_step5->add_member( 'BillingPlan' )->add_string( lv_billing_plan ).
        lo_json_builder_step5->add_member( 'BillingPlanBillingDate' )->add_string( |{ lv_datenow }| ).
        lo_json_builder_step5->add_member( 'BillingPlanAmount' )->add_string( |{ lv_consumption_amt }| ).
        lo_json_builder_step5->add_member( 'BillingPlanDateDescriptionCode' )->add_string( 'Y008' ).


        "--- Scenario A document type ---
        IF lv_scenario EQ 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2'.
            lo_json_builder_step5->add_member( 'ProposedBillingDocumentType' )->add_string( 'FAZ' ).
            lo_json_builder_step5->add_member( 'BillingPlanDateCategory' )->add_string( '04' ).
        ELSE.
            lo_json_builder_step5->add_member( 'ProposedBillingDocumentType' )->add_string( 'F2' ).
            lo_json_builder_step5->add_member( 'BillingPlanDateCategory' )->add_string( '00' ).

        ENDIF.
        lo_json_builder_step5->add_member( 'BillingBlockReason' )->add_string( 'Y4' ).

        lo_json_builder_step5->end_object( ).

        lo_request_body = lo_json_builder_step5->get_data( )->to_string( ).
        lo_request->set_text( lo_request_body ).


        lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).


        http_status = lv_status = lo_response->get_header_field( '~status_code' ).

         lv_step_seq = lv_step_seq + 1.
        zcl_prepay_log=>log_step(
          iv_correlation_id = lv_log_id
          iv_flow_type      = 'BILLPLAN'
          iv_step_seq       = lv_step_seq
          iv_step_name      = 'CREATE_CONSUMPTION_LINE'
          iv_http_method    = 'POST'
          iv_http_status    = http_status
          iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
          iv_response_body  = lo_response->get_text( ) ).

        IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
          zcl_prepay_log=>finish_process(
            iv_log_id       = lv_log_id
            iv_status       = 'E'
            iv_message_text = |Step CREATE_CONSUMPTION_LINE failed with HTTP { http_status }| ).

          APPEND VALUE #(
              %tky = ls_key-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Billing plan posting failed at step CREATE_CONSUMPTION_LINE (HTTP { http_status }). Ref: { lv_log_id }|
                     )
            ) TO reported-prepaymentupdates.

          RETURN.
        ENDIF.

        "--- Save new billing plan item ---
        lv_response_body = lo_response->get_text(  ).
        IF lo_response->get_status( )-code = '201' AND lv_response_body IS NOT INITIAL.
          lv_billing_plan_item = substring_before( val = substring_after( val = lv_response_body
                                                                                     sub = |<d:BillingPlanItem>| )
                                                              sub = |</d:BillingPlanItem>| ).
        ENDIF.

        "--------------------- Check if FULLY COMSUMED CASE -------------------------------------
        DATA lv_fully_consumed TYPE ABAP_BOOL.
        IF lv_remainder_amt = 0.
            lv_fully_consumed = abap_true.
        ELSEIF lv_scenario EQ 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2'.
            IF lv_difference_amt = 0 OR lv_difference_amt < 0 OR ( lv_difference_amt > 0 AND lv_difference_amt < lv_threshold_amt ).
                lv_fully_consumed = abap_true.
            ELSE.
                lv_fully_consumed = abap_false.
            ENDIF.
        ELSE.
            lv_fully_consumed = abap_false.

        ENDIF.
        "--------------------- END Check if FULLY COMSUMED CASE -------------------------------------


        DATA: lv_diff_line_item TYPE string.
        "---------------------REMAINING LINE LOGIC-------------------------------------
        IF lv_remainder_line_item IS NOT INITIAL AND lv_fully_consumed = abap_false.

          "--- Update Remainder Line ---

          lo_request = lo_http_client->get_http_request( ).
          lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }',BillingPlan='{ lv_billing_plan }',BillingPlanItem='{ lv_remainder_line_item }')| ).

          "Set CSRF + Cookie headers
          lo_request->set_header_fields( VALUE #(
            ( name = 'X-CSRF-Token' value = lv_csrf_token )
            ( name = 'Accept'       value = 'application/json' )
            ( name = 'Content-Type' value = 'application/json' )
            ( name = 'Cookie'       value = lv_session )
          ) ).

          "Create payload for POST
          DATA(lo_json_builder_6) = xco_cp_json=>data->builder( ).

          lo_json_builder_6->begin_object( ).
          lo_json_builder_6->add_member( 'BillingPlanAmount' )->add_string( |{ lv_remainder_amt }| ).
          lo_json_builder_6->end_object( ).

          lo_request_body = lo_json_builder_6->get_data( )->to_string( ).
          lo_request->set_text( lo_request_body ).


          lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


          http_status = lv_status = lo_response->get_header_field( '~status_code' ).

            lv_step_seq = lv_step_seq + 1.
            zcl_prepay_log=>log_step(
              iv_correlation_id = lv_log_id
              iv_flow_type      = 'BILLPLAN'
              iv_step_seq       = lv_step_seq
              iv_step_name      = 'UPDATE_REMAINDER_LINE'
              iv_http_method    = 'PATCH'
              iv_http_status    = http_status
              iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
              iv_response_body  = lo_response->get_text( ) ).

            IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
              zcl_prepay_log=>finish_process(
                iv_log_id       = lv_log_id
                iv_status       = 'E'
                iv_message_text = |Step UPDATE_REMAINDER_LINE failed with HTTP { http_status }| ).

              APPEND VALUE #(
                  %tky = ls_key-%tky
                  %msg = new_message_with_text(
                           severity = if_abap_behv_message=>severity-error
                           text     = |Billing plan posting failed at step UPDATE_REMAINDER_LINE (HTTP { http_status }). Ref: { lv_log_id }|
                         )
                ) TO reported-prepaymentupdates.

              RETURN.
            ENDIF.
        ELSEIF lv_remainder_line_item IS INITIAL AND lv_fully_consumed = abap_false.
          "--- ADD Remainder Line ---

          lo_request = lo_http_client->get_http_request( ).
          lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem| ).

          "Set CSRF + Cookie headers
          lo_request->set_header_fields( VALUE #(
            ( name = 'X-CSRF-Token' value = lv_csrf_token )
            ( name = 'Accept'       value = 'application/json' )
            ( name = 'Content-Type' value = 'application/json' )
            ( name = 'Cookie'       value = lv_session )
          ) ).

          "Create payload for POST
          DATA(lo_json_builder_7) = xco_cp_json=>data->builder( ).

          lo_json_builder_7->begin_object( ).
          lo_json_builder_7->add_member( 'SalesOrder' )->add_string( so_number ).
          lo_json_builder_7->add_member( 'SalesOrderItem' )->add_string( |{ so_item }| ).
          lo_json_builder_7->add_member( 'BillingPlan' )->add_string( lv_billing_plan ).
          lo_json_builder_7->add_member( 'BillingPlanBillingDate' )->add_string( |{ lv_datenow }| ).
          lo_json_builder_7->add_member( 'BillingPlanAmount' )->add_string( |{ lv_remainder_amt }| ).
          lo_json_builder_7->add_member( 'BillingPlanDateDescriptionCode' )->add_string( 'Y008' ).
          lo_json_builder_7->add_member( 'ProposedBillingDocumentType' )->add_string( 'F2' ).
          lo_json_builder_7->add_member( 'BillingBlockReason' )->add_string( '' ).


          IF lv_scenario EQ 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2'.
            lo_json_builder_7->add_member( 'BillingPlanDateCategory' )->add_string( '00' ).
          ELSE.
            lo_json_builder_7->add_member( 'BillingPlanDateCategory' )->add_string( '00' ).
          ENDIF.

          lo_json_builder_7->end_object( ).

          lo_request_body = lo_json_builder_7->get_data( )->to_string( ).
          lo_request->set_text( lo_request_body ).


          lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).


          http_status = lv_status = lo_response->get_header_field( '~status_code' ).

          lv_step_seq = lv_step_seq + 1.
            zcl_prepay_log=>log_step(
              iv_correlation_id = lv_log_id
              iv_flow_type      = 'BILLPLAN'
              iv_step_seq       = lv_step_seq
              iv_step_name      = 'CREATE_REMAINDER_LINE'
              iv_http_method    = 'POST'
              iv_http_status    = http_status
              iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
              iv_response_body  = lo_response->get_text( ) ).

            IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
              zcl_prepay_log=>finish_process(
                iv_log_id       = lv_log_id
                iv_status       = 'E'
                iv_message_text = |Step CREATE_REMAINDER_LINE failed with HTTP { http_status }| ).

              APPEND VALUE #(
                  %tky = ls_key-%tky
                  %msg = new_message_with_text(
                           severity = if_abap_behv_message=>severity-error
                           text     = |Billing plan posting failed at step CREATE_REMAINDER_LINE (HTTP { http_status }). Ref: { lv_log_id }|
                         )
                ) TO reported-prepaymentupdates.

              RETURN.
            ENDIF.
        ELSEIF lv_remainder_line_item IS NOT INITIAL AND lv_fully_consumed = abap_true.


          "--- Add billing block to SO Item Line for scenario B and C ---

          IF lv_scenario EQ 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2'.
              "Add Total Amount Applied line -- update remaining line with ammount applied
                lo_request = lo_http_client->get_http_request( ).
                lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }',BillingPlan='{ lv_billing_plan }',BillingPlanItem='{ lv_remainder_line_item }')| ).

                "Set CSRF + Cookie headers
                lo_request->set_header_fields( VALUE #(
                  ( name = 'X-CSRF-Token' value = lv_csrf_token )
                  ( name = 'Accept'       value = 'application/xml' )
                  ( name = 'Content-Type' value = 'application/json' )
                  ( name = 'Cookie'       value = lv_session )
                ) ).

                "Create payload for POST
                DATA(lo_json_builder_step9) = xco_cp_json=>data->builder( ).

                lo_json_builder_step9->begin_object( ).
                lo_json_builder_step9->add_member( 'BillingPlanAmount' )->add_string( |{ lv_amount_applied_A }| ).
                lo_json_builder_step9->end_object( ).

                lo_request_body = lo_json_builder_step9->get_data( )->to_string( ).
                lo_request->set_text( lo_request_body ).


                lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


                http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                lv_step_seq = lv_step_seq + 1.
                zcl_prepay_log=>log_step(
                  iv_correlation_id = lv_log_id
                  iv_flow_type      = 'BILLPLAN'
                  iv_step_seq       = lv_step_seq
                  iv_step_name      = 'UPDATE_TOTAL_APPLIED_LINE'
                  iv_http_method    = 'PATCH'
                  iv_http_status    = http_status
                  iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                  iv_response_body  = lo_response->get_text( ) ).

                IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                  zcl_prepay_log=>finish_process(
                    iv_log_id       = lv_log_id
                    iv_status       = 'E'
                    iv_message_text = |Step UPDATE_TOTAL_APPLIED_LINE failed with HTTP { http_status }| ).

                  APPEND VALUE #(
                      %tky = ls_key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Billing plan posting failed at step UPDATE_TOTAL_APPLIED_LINE (HTTP { http_status }). Ref: { lv_log_id }|
                             )
                    ) TO reported-prepaymentupdates.

                  RETURN.
                ENDIF.

                IF lv_difference_amt < lv_threshold_amt and lv_difference_amt > 0.
                    "--------------------- Add difference amount  -------------------------------------
                    lo_request = lo_http_client->get_http_request( ).
                    lo_request->set_uri_path( '/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem' ).

                    "Set CSRF + Cookie headers
                    lo_request->set_header_fields( VALUE #(
                      ( name = 'X-CSRF-Token' value = lv_csrf_token )
                      ( name = 'Accept'       value = 'application/xml' )
                      ( name = 'Content-Type' value = 'application/json' )
                      ( name = 'Cookie'       value = lv_session )
                    ) ).

                    "Create payload for POST
                    DATA(lo_json_builder_10) = xco_cp_json=>data->builder( ).

                    lo_json_builder_10->begin_object( ).
                    lo_json_builder_10->add_member( 'SalesOrder' )->add_string( so_number ).
                    lo_json_builder_10->add_member( 'SalesOrderItem' )->add_string( |{ so_item }| ).
                    lo_json_builder_10->add_member( 'BillingPlan' )->add_string( lv_billing_plan ).
                    lo_json_builder_10->add_member( 'BillingPlanBillingDate' )->add_string( |{ lv_datenow }| ).
                    lo_json_builder_10->add_member( 'BillingPlanAmount' )->add_string( |{ abs( lv_difference_amt )  }| ).
                    lo_json_builder_10->add_member( 'BillingPlanDateDescriptionCode' )->add_string( 'Y008' ).
                    lo_json_builder_10->add_member( 'ProposedBillingDocumentType' )->add_string( 'FAZ' ).

                    lo_json_builder_10->add_member( 'BillingBlockReason' )->add_string( 'Z1' ).
                    lo_json_builder_10->add_member( 'BillingPlanDateCategory' )->add_string( '00' ).
                    lo_json_builder_10->end_object( ).

                    lo_request_body = lo_json_builder_10->get_data( )->to_string( ).
                    lo_request->set_text( lo_request_body ).


                    lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).


                    http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                    lv_step_seq = lv_step_seq + 1.
                    zcl_prepay_log=>log_step(
                      iv_correlation_id = lv_log_id
                      iv_flow_type      = 'BILLPLAN'
                      iv_step_seq       = lv_step_seq
                      iv_step_name      = 'CREATE_DIFFERENCE_LINE'
                      iv_http_method    = 'POST'
                      iv_http_status    = http_status
                      iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                      iv_response_body  = lo_response->get_text( ) ).

                    IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                      zcl_prepay_log=>finish_process(
                        iv_log_id       = lv_log_id
                        iv_status       = 'E'
                        iv_message_text = |Step CREATE_DIFFERENCE_LINE failed with HTTP { http_status }| ).

                      APPEND VALUE #(
                          %tky = ls_key-%tky
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = |Billing plan posting failed at step CREATE_DIFFERENCE_LINE (HTTP { http_status }). Ref: { lv_log_id }|
                                 )
                        ) TO reported-prepaymentupdates.

                      RETURN.
                    ENDIF.

                    "--- Save diff line billing plan item ---

                    lv_response_body = lo_response->get_text(  ).
                    IF lo_response->get_status( )-code = '201' AND lv_response_body IS NOT INITIAL.
                      lv_diff_line_item = substring_before( val = substring_after( val = lv_response_body
                                                                                                 sub = |<d:BillingPlanItem>| )
                                                                          sub = |</d:BillingPlanItem>| ).
                    ENDIF.
                ENDIF.
          ELSE.
                "--- DELETE Remainder Line ---

              lo_request = lo_http_client->get_http_request( ).
              lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }',BillingPlan='{ lv_billing_plan }',BillingPlanItem='{ lv_remainder_line_item }')| ).

              "Set CSRF + Cookie headers
              lo_request->set_header_fields( VALUE #(
                ( name = 'X-CSRF-Token' value = lv_csrf_token )
                ( name = 'Accept'       value = 'application/json' )
                ( name = 'Content-Type' value = 'application/json' )
                ( name = 'Cookie'       value = lv_session )
              ) ).

              lo_response = lo_http_client->execute( i_method = if_web_http_client=>delete ).


              http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                lv_step_seq = lv_step_seq + 1.
                zcl_prepay_log=>log_step(
                  iv_correlation_id = lv_log_id
                  iv_flow_type      = 'BILLPLAN'
                  iv_step_seq       = lv_step_seq
                  iv_step_name      = 'DELETE_REMAINDER_LINE'
                  iv_http_method    = 'DELETE'
                  iv_http_status    = http_status
                  iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                  iv_response_body  = lo_response->get_text( ) ).

                IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                  zcl_prepay_log=>finish_process(
                    iv_log_id       = lv_log_id
                    iv_status       = 'E'
                    iv_message_text = |Step DELETE_REMAINDER_LINE failed with HTTP { http_status }| ).

                  APPEND VALUE #(
                      %tky = ls_key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Billing plan posting failed at step DELETE_REMAINDER_LINE (HTTP { http_status }). Ref: { lv_log_id }|
                             )
                    ) TO reported-prepaymentupdates.

                  RETURN.
                ENDIF.

               "--- END DELETE Remainder Line ---

              lo_request = lo_http_client->get_http_request( ).
              lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }')| ).

              "Set CSRF + Cookie headers
              lo_request->set_header_fields( VALUE #(
                ( name = 'X-CSRF-Token' value = lv_csrf_token )
                ( name = 'Accept'       value = 'application/json' )
                ( name = 'Content-Type' value = 'application/json' )
                ( name = 'Cookie'       value = lv_session )
              ) ).

              "Create payload for POST
              DATA(lo_json_builder_8) = xco_cp_json=>data->builder( ).

              lo_json_builder_8->begin_object( ).
              lo_json_builder_8->add_member( 'ItemBillingBlockReason' )->add_string( '01' ).
              lo_json_builder_8->end_object( ).

              lo_request_body = lo_json_builder_8->get_data( )->to_string( ).
              lo_request->set_text( lo_request_body ).


              lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


              http_status = lv_status = lo_response->get_header_field( '~status_code' ).

              lv_step_seq = lv_step_seq + 1.
                zcl_prepay_log=>log_step(
                  iv_correlation_id = lv_log_id
                  iv_flow_type      = 'BILLPLAN'
                  iv_step_seq       = lv_step_seq
                  iv_step_name      = 'UPDATE_BILLING_BLOCK'
                  iv_http_method    = 'PATCH'
                  iv_http_status    = http_status
                  iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                  iv_response_body  = lo_response->get_text( ) ).

                IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                  zcl_prepay_log=>finish_process(
                    iv_log_id       = lv_log_id
                    iv_status       = 'E'
                    iv_message_text = |Step UPDATE_BILLING_BLOCK failed with HTTP { http_status }| ).

                  APPEND VALUE #(
                      %tky = ls_key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Billing plan posting failed at step UPDATE_BILLING_BLOCK (HTTP { http_status }). Ref: { lv_log_id }|
                             )
                    ) TO reported-prepaymentupdates.

                  RETURN.
                ENDIF.
          ENDIF.


        ELSE.
          "--- No remaining line + zero remaining amount (Amount to pay = SO amount) ---
          "--- Add billing block to SO Item Line ---

          IF lv_scenario = 'A' or lv_scenario EQ 'D1' or lv_scenario EQ 'D2'.
                "Add Total Amount Applied line
                lo_request = lo_http_client->get_http_request( ).
                lo_request->set_uri_path( '/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem' ).

                "Set CSRF + Cookie headers
                lo_request->set_header_fields( VALUE #(
                  ( name = 'X-CSRF-Token' value = lv_csrf_token )
                  ( name = 'Accept'       value = 'application/xml' )
                  ( name = 'Content-Type' value = 'application/json' )
                  ( name = 'Cookie'       value = lv_session )
                ) ).

                "Create payload for POST
                DATA(lo_json_builder_step12) = xco_cp_json=>data->builder( ).

                lo_json_builder_step12->begin_object( ).
                lo_json_builder_step12->add_member( 'SalesOrder' )->add_string( so_number ).
                lo_json_builder_step12->add_member( 'SalesOrderItem' )->add_string( |{ so_item }| ).
                lo_json_builder_step12->add_member( 'BillingPlan' )->add_string( lv_billing_plan ).
                lo_json_builder_step12->add_member( 'BillingPlanBillingDate' )->add_string( |{ lv_datenow }| ).
                lo_json_builder_step12->add_member( 'BillingPlanAmount' )->add_string( |{ lv_amount_applied_A }| ).
                lo_json_builder_step12->add_member( 'BillingPlanDateDescriptionCode' )->add_string( 'Y008' ).
                lo_json_builder_step12->add_member( 'ProposedBillingDocumentType' )->add_string( 'F2' ).
                lo_json_builder_step12->add_member( 'BillingPlanBillingRule' )->add_string( '2' ).
                lo_json_builder_step12->add_member( 'BillingBlockReason' )->add_string( '' ).
                lo_json_builder_step12->add_member( 'BillingPlanDateCategory' )->add_string( '00' ).
                lo_json_builder_step12->end_object( ).

                lo_request_body = lo_json_builder_step12->get_data( )->to_string( ).
                lo_request->set_text( lo_request_body ).


                lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).


                http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                lv_step_seq = lv_step_seq + 1.
                zcl_prepay_log=>log_step(
                  iv_correlation_id = lv_log_id
                  iv_flow_type      = 'BILLPLAN'
                  iv_step_seq       = lv_step_seq
                  iv_step_name      = 'CREATE_TOTAL_APPLIED_LINE'
                  iv_http_method    = 'POST'
                  iv_http_status    = http_status
                  iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                  iv_response_body  = lo_response->get_text( ) ).

                IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                  zcl_prepay_log=>finish_process(
                    iv_log_id       = lv_log_id
                    iv_status       = 'E'
                    iv_message_text = |Step CREATE_TOTAL_APPLIED_LINE failed with HTTP { http_status }| ).

                  APPEND VALUE #(
                      %tky = ls_key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Billing plan posting failed at step CREATE_TOTAL_APPLIED_LINE (HTTP { http_status }). Ref: { lv_log_id }|
                             )
                    ) TO reported-prepaymentupdates.

                  RETURN.
                ENDIF.

                IF lv_difference_amt < lv_threshold_amt and lv_difference_amt > 0.
                    "--------------------- Add difference amount  -------------------------------------
                    lo_request = lo_http_client->get_http_request( ).
                    lo_request->set_uri_path( '/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem' ).

                    "Set CSRF + Cookie headers
                    lo_request->set_header_fields( VALUE #(
                      ( name = 'X-CSRF-Token' value = lv_csrf_token )
                      ( name = 'Accept'       value = 'application/xml' )
                      ( name = 'Content-Type' value = 'application/json' )
                      ( name = 'Cookie'       value = lv_session )
                    ) ).

                    "Create payload for POST
                    DATA(lo_json_builder_13) = xco_cp_json=>data->builder( ).

                    lo_json_builder_13->begin_object( ).
                    lo_json_builder_13->add_member( 'SalesOrder' )->add_string( so_number ).
                    lo_json_builder_13->add_member( 'SalesOrderItem' )->add_string( |{ so_item }| ).
                    lo_json_builder_13->add_member( 'BillingPlan' )->add_string( lv_billing_plan ).
                    lo_json_builder_13->add_member( 'BillingPlanBillingDate' )->add_string( |{ lv_datenow }| ).
                    lo_json_builder_13->add_member( 'BillingPlanAmount' )->add_string( |{ abs( lv_difference_amt )  }| ).
                    lo_json_builder_13->add_member( 'BillingPlanDateDescriptionCode' )->add_string( 'Y008' ).
                    lo_json_builder_13->add_member( 'ProposedBillingDocumentType' )->add_string( 'FAZ' ).

                    lo_json_builder_13->add_member( 'BillingBlockReason' )->add_string( 'Z1' ).
                    lo_json_builder_13->add_member( 'BillingPlanDateCategory' )->add_string( '00' ).
                    lo_json_builder_13->end_object( ).

                    lo_request_body = lo_json_builder_13->get_data( )->to_string( ).
                    lo_request->set_text( lo_request_body ).


                    lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).


                    http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                    lv_step_seq = lv_step_seq + 1.
                    zcl_prepay_log=>log_step(
                      iv_correlation_id = lv_log_id
                      iv_flow_type      = 'BILLPLAN'
                      iv_step_seq       = lv_step_seq
                      iv_step_name      = 'CREATE_DIFFERENCE_LINE'
                      iv_http_method    = 'POST'
                      iv_http_status    = http_status
                      iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
                      iv_response_body  = lo_response->get_text( ) ).

                    IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
                      zcl_prepay_log=>finish_process(
                        iv_log_id       = lv_log_id
                        iv_status       = 'E'
                        iv_message_text = |Step CREATE_DIFFERENCE_LINE failed with HTTP { http_status }| ).

                      APPEND VALUE #(
                          %tky = ls_key-%tky
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = |Billing plan posting failed at step CREATE_DIFFERENCE_LINE (HTTP { http_status }). Ref: { lv_log_id }|
                                 )
                        ) TO reported-prepaymentupdates.

                      RETURN.
                    ENDIF.
                    lv_response_body = lo_response->get_text(  ).
                    IF lo_response->get_status( )-code = '201' AND lv_response_body IS NOT INITIAL.
                      lv_diff_line_item = substring_before( val = substring_after( val = lv_response_body
                                                                                                 sub = |<d:BillingPlanItem>| )
                                                                          sub = |</d:BillingPlanItem>| ).
                    ENDIF.
                ENDIF.

          ELSE.
              lo_request = lo_http_client->get_http_request( ).
              lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ so_number }',SalesOrderItem='{ so_item }')| ).

              "Set CSRF + Cookie headers
              lo_request->set_header_fields( VALUE #(
                ( name = 'X-CSRF-Token' value = lv_csrf_token )
                ( name = 'Accept'       value = 'application/json' )
                ( name = 'Content-Type' value = 'application/json' )
                ( name = 'Cookie'       value = lv_session )
              ) ).

              "Create payload for POST
              DATA(lo_json_builder_9) = xco_cp_json=>data->builder( ).

              lo_json_builder_9->begin_object( ).
              lo_json_builder_9->add_member( 'ItemBillingBlockReason' )->add_string( '01' ).
              lo_json_builder_9->end_object( ).

              lo_request_body = lo_json_builder_9->get_data( )->to_string( ).
              lo_request->set_text( lo_request_body ).


              lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


              http_status = lv_status = lo_response->get_header_field( '~status_code' ).

              lv_step_seq = lv_step_seq + 1.
            zcl_prepay_log=>log_step(
              iv_correlation_id = lv_log_id
              iv_flow_type      = 'BILLPLAN'
              iv_step_seq       = lv_step_seq
              iv_step_name      = 'UPDATE_BILLING_BLOCK'
              iv_http_method    = 'PATCH'
              iv_http_status    = http_status
              iv_uri            = lo_request->get_header_field( i_name = '~request_uri' )
              iv_response_body  = lo_response->get_text( ) ).

            IF CONV i( http_status ) < 200 OR CONV i( http_status ) >= 300.
              zcl_prepay_log=>finish_process(
                iv_log_id       = lv_log_id
                iv_status       = 'E'
                iv_message_text = |Step UPDATE_BILLING_BLOCK failed with HTTP { http_status }| ).

              APPEND VALUE #(
                  %tky = ls_key-%tky
                  %msg = new_message_with_text(
                           severity = if_abap_behv_message=>severity-error
                           text     = |Billing plan posting failed at step UPDATE_BILLING_BLOCK (HTTP { http_status }). Ref: { lv_log_id }|
                         )
                ) TO reported-prepaymentupdates.

              RETURN.
            ENDIF.
          ENDIF.


        ENDIF.


        "--- Build return structure ---
        DATA ls_type_result TYPE zi_Prepayment_Updates.
        ls_type_result-prepaymentsoitem = |{ lv_billing_plan_item }{ COND string( WHEN lv_diff_line_item IS NOT INITIAL THEN |#{ lv_diff_line_item }| ) }|.

        zcl_prepay_log=>finish_process(
          iv_log_id = lv_log_id
          iv_status = 'S' ).

        LOOP AT keys INTO DATA(ls_key_res).

          APPEND VALUE #( %tky = ls_key_res-%tky
                %param = CORRESPONDING #( ls_type_result ) ) TO result.

        ENDLOOP.
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lo_http_error1).
        zcl_prepay_log=>finish_process(
          iv_log_id       = lv_log_id
          iv_status       = 'E'
          iv_message_text = lo_http_error1->get_text( ) ).

        LOOP AT keys INTO DATA(ls_key_err1).
          APPEND VALUE #(
              %tky = ls_key_err1-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Sales order communication failed: { lo_http_error1->get_text( ) } (ref: { lv_log_id })|
                     )
            ) TO reported-prepaymentupdates.
        ENDLOOP.

      CATCH cx_root INTO DATA(lo_unexpected1).
        zcl_prepay_log=>finish_process(
          iv_log_id       = lv_log_id
          iv_status       = 'E'
          iv_message_text = lo_unexpected1->get_text( ) ).

        LOOP AT keys INTO DATA(ls_key_err2).
          APPEND VALUE #(
              %tky = ls_key_err2-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Unexpected error posting billing plan: { lo_unexpected1->get_text( ) } (ref: { lv_log_id })|
                     )
            ) TO reported-prepaymentupdates.
        ENDLOOP.
    ENDTRY.




  ENDMETHOD.

  METHOD reverseBillingPlan.

    DATA lv_so_number         TYPE string.
    DATA lv_so_item           TYPE string.
    DATA lv_billing_plan_item TYPE i.
    DATA lv_billing_plan      TYPE string.
    DATA lv_scenario      TYPE string.

    LOOP AT keys INTO DATA(ls_key).
      lv_so_number         = ls_key-delvSoSalesDocument.
      lv_so_item           = ls_key-delvSoSalesDocumentItem.
      lv_billing_plan_item = ls_key-%param-param_billingplanitem.
      lv_scenario          = ls_key-%param-param_scenario.
    ENDLOOP.

    DATA lv_status     TYPE i.

    DATA lv_csrf_token TYPE string.
    DATA lv_session    TYPE string.
    DATA http_status    TYPE string.
    DATA rv_result    TYPE string.
    DATA lo_request_body TYPE string.
    DATA lv_response_body TYPE string.
    DATA lo_response TYPE REF TO if_web_http_response.
    DATA lo_request TYPE REF TO if_web_http_request.



*    TYPES: BEGIN OF ty_result,
*             billingplannum  TYPE string,
*             billingplanitem TYPE string,
*           END OF ty_result.

    TRY.
        "--- HTTP CLIENT ---
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                 comm_scenario = 'ZCS_PREPAYMENT_CONSUMPTION'
                                 service_id    = 'ZOS_SALES_ORDER_V2_REST' ).

        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination(
                                 i_destination = lo_destination ).

        "--- STEP 1.1: Get billing plan number ---
        SELECT SINGLE
               billingplan,
               customergroup
          FROM i_salesdocumentitem
          WHERE salesdocument     = @lv_so_number
            AND salesdocumentitem = @lv_so_item
          INTO (@lv_billing_plan, @DATA(lv_customer_grp)).

        "--- STEP 2: Get Billing Plan items ---
        TYPES: BEGIN OF ty_billingplanitem,
                 BillingPlan        TYPE string,
                 BillingPlanItem    TYPE string,
                 BillingPlanAmount  TYPE string,
                 BillingBlockReason TYPE string,
               END OF ty_billingplanitem.

        TYPES: tt_billingplanitems TYPE STANDARD TABLE OF ty_billingplanitem WITH DEFAULT KEY.

        TYPES: BEGIN OF ty_d,
                 results TYPE tt_billingplanitems,
               END OF ty_d.

        TYPES: BEGIN OF ty_wrapper,
                 d TYPE ty_d,
               END OF ty_wrapper.


        DATA: lv_json        TYPE string,
              ls_wrapper     TYPE ty_wrapper,
              lt_billingplan TYPE tt_billingplanitems.

        lo_http_client->accept_cookies( abap_true ).
        lo_request = lo_http_client->get_http_request( ).

        lo_request->set_uri_path( |/A_SalesOrderItemBillingPlan(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }',BillingPlan='{ lv_billing_plan }')/to_BillingPlanItem| ).
        lo_request->set_header_fields( VALUE #(
          ( name = 'X-CSRF-Token' value = 'fetch' )
          ( name = 'Accept'       value = 'application/json' )
        ) ).

        lo_response = lo_http_client->execute( i_method = if_web_http_client=>get ).
        http_status = lv_status = lo_response->get_header_field( '~status_code' ).
        lv_csrf_token = lo_response->get_header_field( 'X-CSRF-Token' ).

        "Debug
        DATA(lv_body_debug1)   = lo_request->get_text( ).
        DATA(lt_headers_debug1) = lo_request->get_header_fields( ).
        DATA(lv_method_debug1) = lo_request->get_method( ).
        DATA(lv_res_debug1) = lo_response->get_text( ).
        DATA(lt_res_headers1) = lo_response->get_header_fields( ).
        DATA(lv_path_debug1) = lo_request->get_header_field( i_name = '~request_uri' ).

        "end debug

        "--------- Parse Response-------------
        lv_json = lo_response->get_text( ).
        /ui2/cl_json=>deserialize(
                      EXPORTING
                        json        = lv_json
                        pretty_name = /ui2/cl_json=>pretty_mode-none
                      CHANGING
                        data        = ls_wrapper ).
        lt_billingplan = ls_wrapper-d-results.

        "--------- End Parse Response---------

        "--------- Get Line with Remaining amount -------------
        DATA lv_remainder_line_item TYPE string.
        DATA lv_remainder_amt TYPE p DECIMALS 2.
        DATA lv_index TYPE i.


        " Scenario A
        DATA lv_total_amt_applied_index TYPE i.
        DATA lv_total_amt_applied_line_item TYPE string.
        DATA lv_total_amt_applied_amt TYPE p DECIMALS 2.

        IF lv_customer_grp = '07'.
            LOOP AT lt_billingplan INTO DATA(ls_item_1).
                IF ls_item_1-billingblockreason IS INITIAL.
                    lv_total_amt_applied_line_item = ls_item_1-billingplanitem.
                    lv_total_amt_applied_amt = ls_item_1-billingplanamount.
                    lv_total_amt_applied_index = sy-tabix.
                    EXIT. " stop after the first match
                ENDIF.
            ENDLOOP.
        ELSE.
            LOOP AT lt_billingplan INTO DATA(ls_item_2).
                IF ls_item_2-billingblockreason IS INITIAL.
                    lv_remainder_line_item = ls_item_2-billingplanitem.
                    lv_remainder_amt = ls_item_2-billingplanamount.
                    lv_index = sy-tabix.
                    EXIT. " stop after the first match
                ENDIF.
            ENDLOOP.
        ENDIF.

        "--------- End Get Line with Remaining amount ---------

        "--- DELETE Billing Plan Line ---

        lo_request = lo_http_client->get_http_request( ).
        lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }',BillingPlan='{ lv_billing_plan }',BillingPlanItem='{ lv_billing_plan_item }')| ).

        "Set CSRF + Cookie headers
        lo_request->set_header_fields( VALUE #(
          ( name = 'X-CSRF-Token' value = lv_csrf_token )
          ( name = 'Accept'       value = 'application/json' )
          ( name = 'Content-Type' value = 'application/json' )
          ( name = 'Cookie'       value = lv_session )
        ) ).

        lo_response = lo_http_client->execute( i_method = if_web_http_client=>delete ).


        http_status = lv_status = lo_response->get_header_field( '~status_code' ).

        "Debug
        DATA(lv_body_debug2)   = lo_request->get_text( ).
        DATA(lt_headers_debug2) = lo_request->get_header_fields( ).
        DATA(lv_method_debug2) = lo_request->get_method( ).
        DATA(lv_res_debug2) = lo_response->get_text( ).
        DATA(lt_res_headers2) = lo_response->get_header_fields( ).
        DATA(lv_path_debug2) = lo_request->get_header_field( i_name = '~request_uri' ).

        "end debug

        "--- END DELETE Billing Plan Line ---

        DATA lv_new_amt TYPE p DECIMALS 2.

        DATA(lv_found_amt) = VALUE #( lt_billingplan[ billingplanitem = |{ lv_billing_plan_item }| ]-billingplanamount ).


        IF lv_scenario = 'A' AND lv_customer_grp = '07'. "Line is total amount applied line
            " Total amount applied - amount reversed
            lv_new_amt = lv_total_amt_applied_amt - lv_found_amt.
        ELSE.
            "Line is remainder line
            lv_new_amt = lv_found_amt + lv_remainder_amt.
        ENDIF.

        DELETE lt_billingplan WHERE billingplanitem = lv_billing_plan_item.

        DATA(lv_count) = lines( lt_billingplan ).

        IF lv_status >= 200 AND lv_status < 300.
            IF lv_remainder_line_item IS NOT INITIAL OR lv_total_amt_applied_line_item IS NOT INITIAL.
                IF lv_count = 1. " Only remaining amount line or total amount applied line remains
                    "--- DELETE Remainder/Total amount applied Line ---

                    lo_request = lo_http_client->get_http_request( ).
                    lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }',BillingPlan='{ lv_billing_plan }',BillingPlanItem='{ lv_remainder_line_item
}')| ).

                    "Set CSRF + Cookie headers
                    lo_request->set_header_fields( VALUE #(
                      ( name = 'X-CSRF-Token' value = lv_csrf_token )
                      ( name = 'Accept'       value = 'application/json' )
                      ( name = 'Content-Type' value = 'application/json' )
                      ( name = 'Cookie'       value = lv_session )
                    ) ).

                    lo_response = lo_http_client->execute( i_method = if_web_http_client=>delete ).


                    http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                    "Debug
                    DATA(lv_body_debug4)   = lo_request->get_text( ).
                    DATA(lt_headers_debug4) = lo_request->get_header_fields( ).
                    DATA(lv_method_debug4) = lo_request->get_method( ).
                    DATA(lv_res_debug4) = lo_response->get_text( ).
                    DATA(lt_res_headers4) = lo_response->get_header_fields( ).
                    DATA(lv_path_debug4) = lo_request->get_header_field( i_name = '~request_uri' ).

                    "end debug
                    "--- END DELETE Remainder Line ---

                    "--- Remove billing block in SO Item Line ---

                      lo_request = lo_http_client->get_http_request( ).
                      lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }')| ).

                      "Set CSRF + Cookie headers
                      lo_request->set_header_fields( VALUE #(
                        ( name = 'X-CSRF-Token' value = lv_csrf_token )
                        ( name = 'Accept'       value = 'application/json' )
                        ( name = 'Content-Type' value = 'application/json' )
                        ( name = 'Cookie'       value = lv_session )
                      ) ).

                      "Create payload for POST
                      DATA(lo_json_builder_9) = xco_cp_json=>data->builder( ).

                      lo_json_builder_9->begin_object( ).

                      " IF scenario A change back customer group
                      IF lv_scenario = 'A'.
                        lo_json_builder_9->add_member( 'CustomerGroup' )->add_string( '' ).
                      ELSE.
                        lo_json_builder_9->add_member( 'ItemBillingBlockReason' )->add_string( '' ).
                      ENDIF.

                      lo_json_builder_9->end_object( ).

                      lo_request_body = lo_json_builder_9->get_data( )->to_string( ).
                      lo_request->set_text( lo_request_body ).


                      lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


                      http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                    "--- Update SO Item Category ---
                      lo_request->set_uri_path(
                    |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }')| ).

                      lo_request->set_header_fields( VALUE #(
                        ( name = 'X-CSRF-Token' value = lv_csrf_token )
                        ( name = 'Accept'       value = 'application/json' )
                        ( name = 'Content-Type' value = 'application/json' )
                        ( name = 'Cookie'       value = lv_session )
                      ) ).

                      "Create payload for PATCH
                      DATA(lo_json_builder_step2) = xco_cp_json=>data->builder( ).

                      lo_json_builder_step2->begin_object( ).
                      lo_json_builder_step2->add_member( 'SalesOrderItemCategory' )->add_string( 'TAD' ).
                      lo_json_builder_step2->add_member( 'BillingPlan' )->add_string( '' ).
                      lo_json_builder_step2->end_object( ).

                      lo_request_body = lo_json_builder_step2->get_data( )->to_string( ).
                      lo_request->set_text( lo_request_body ).



                      lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


                      http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                      "Debug
                      DATA(lv_body_debug5)   = lo_request->get_text( ).
                      DATA(lt_headers_debug5) = lo_request->get_header_fields( ).
                      DATA(lv_method_debug5) = lo_request->get_method( ).
                      DATA(lv_res_debug5) = lo_response->get_text( ).
                      DATA(lt_res_headers5) = lo_response->get_header_fields( ).
                      DATA(lv_path_debug5) = lo_request->get_header_field( i_name = '~request_uri' ).
                      "end debug

                       " -------------- Update IsprepaymentDelveryForm flag-----------------
                           lo_request->set_uri_path(
                        |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }')| ).

                          lo_request->set_header_fields( VALUE #(
                            ( name = 'X-CSRF-Token' value = lv_csrf_token )
                            ( name = 'Accept'       value = 'application/json' )
                            ( name = 'Content-Type' value = 'application/json' )
                            ( name = 'Cookie'       value = lv_session )
                             ( name = 'If-Match'     value = '*' )
                          ) ).

                          "Create payload for PATCH d
                          DATA(lo_json_builder_flag) = xco_cp_json=>data->builder( ).

                          lo_json_builder_flag->begin_object( ).
                          lo_json_builder_flag->add_member( 'YY1_ISPREPAYDELVFORM_SDI' )->add_string( 'N' ).

                          lo_json_builder_flag->end_object( ).

                          lo_request_body = lo_json_builder_flag->get_data( )->to_string( ).
                          lo_request->set_text( lo_request_body ).

                          lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).
                          http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                          lo_request->delete_header_field( 'If-Match' ).

                           " -------------- END Update IsprepaymentDelveryForm flag-----------------

                ELSE.
                    " Some lines remain
                    "--- Update Remainder or Total Applied Line with new amount  ---

                      lo_request = lo_http_client->get_http_request( ).
                      lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }',BillingPlan='{ lv_billing_plan }',BillingPlanItem='{
        lv_remainder_line_item }')| ).

                      "Set CSRF + Cookie headers
                      lo_request->set_header_fields( VALUE #(
                        ( name = 'X-CSRF-Token' value = lv_csrf_token )
                        ( name = 'Accept'       value = 'application/json' )
                        ( name = 'Content-Type' value = 'application/json' )
                        ( name = 'Cookie'       value = lv_session )
                      ) ).

                      "Create payload for POST
                      DATA(lo_json_builder_6) = xco_cp_json=>data->builder( ).

                      lo_json_builder_6->begin_object( ).
                      lo_json_builder_6->add_member( 'BillingPlanAmount' )->add_string( |{ lv_new_amt }| ).
                      lo_json_builder_6->end_object( ).

                      lo_request_body = lo_json_builder_6->get_data( )->to_string( ).
                      lo_request->set_text( lo_request_body ).


                      lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


                      http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                      "Debug
                      DATA(lv_body_debug3)   = lo_request->get_text( ).
                      DATA(lt_headers_debug3) = lo_request->get_header_fields( ).
                      DATA(lv_method_debug3) = lo_request->get_method( ).
                      DATA(lv_res_debug3) = lo_response->get_text( ).
                      DATA(lt_res_headers3) = lo_response->get_header_fields( ).
                      DATA(lv_path_debug3) = lo_request->get_header_field( i_name = '~request_uri' ).

                      "end debug

                      "IF customer group is 07 change it to null
                      IF lv_customer_grp IS NOT INITIAL.
                         "--- Update customer group in SO Item Line ---

                          lo_request = lo_http_client->get_http_request( ).
                          lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }')| ).

                          "Set CSRF + Cookie headers
                          lo_request->set_header_fields( VALUE #(
                            ( name = 'X-CSRF-Token' value = lv_csrf_token )
                            ( name = 'Accept'       value = 'application/json' )
                            ( name = 'Content-Type' value = 'application/json' )
                            ( name = 'Cookie'       value = lv_session )
                          ) ).

                          "Create payload for POST
                          DATA(lo_json_builder_10) = xco_cp_json=>data->builder( ).

                          lo_json_builder_10->begin_object( ).
                          lo_json_builder_10->add_member( 'CustomerGroup' )->add_string( '' ).
                          lo_json_builder_10->end_object( ).

                          lo_request_body = lo_json_builder_10->get_data( )->to_string( ).
                          lo_request->set_text( lo_request_body ).

                          lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).

                          http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                      ENDIF.

                ENDIF.
            ELSE.
                " No lines in billing plan
                IF lv_count = 0.
                    "--- Remove billing block in SO Item Line ---

                      lo_request = lo_http_client->get_http_request( ).
                      lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }')| ).

                      "Set CSRF + Cookie headers
                      lo_request->set_header_fields( VALUE #(
                        ( name = 'X-CSRF-Token' value = lv_csrf_token )
                        ( name = 'Accept'       value = 'application/json' )
                        ( name = 'Content-Type' value = 'application/json' )
                        ( name = 'Cookie'       value = lv_session )
                      ) ).

                      "Create payload for POST
                      DATA(lo_json_builder_8) = xco_cp_json=>data->builder( ).

                      lo_json_builder_8->begin_object( ).
                      lo_json_builder_8->add_member( 'ItemBillingBlockReason' )->add_string( '' ).
                      lo_json_builder_8->end_object( ).

                      lo_request_body = lo_json_builder_8->get_data( )->to_string( ).
                      lo_request->set_text( lo_request_body ).


                      lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


                      http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                    "--- Update SO Item Category ---
                      lo_request->set_uri_path(
                    |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }')| ).

                      lo_request->set_header_fields( VALUE #(
                        ( name = 'X-CSRF-Token' value = lv_csrf_token )
                        ( name = 'Accept'       value = 'application/json' )
                        ( name = 'Content-Type' value = 'application/json' )
                        ( name = 'Cookie'       value = lv_session )
                      ) ).

                      "Create payload for PATCH
                      DATA(lo_json_builder_1) = xco_cp_json=>data->builder( ).

                      lo_json_builder_1->begin_object( ).
                      lo_json_builder_1->add_member( 'SalesOrderItemCategory' )->add_string( 'TAD' ).
                      lo_json_builder_1->add_member( 'BillingPlan' )->add_string( '' ).
                      lo_json_builder_1->end_object( ).

                      lo_request_body = lo_json_builder_1->get_data( )->to_string( ).
                      lo_request->set_text( lo_request_body ).



                      lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).


                      http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                      "Debug
                      DATA(lv_body_debug6)   = lo_request->get_text( ).
                      DATA(lt_headers_debug6) = lo_request->get_header_fields( ).
                      DATA(lv_method_debug6) = lo_request->get_method( ).
                      DATA(lv_res_debug6) = lo_response->get_text( ).
                      DATA(lt_res_headers6) = lo_response->get_header_fields( ).
                      DATA(lv_path_debug6) = lo_request->get_header_field( i_name = '~request_uri' ).
                      "end debug

                  " -------------- Update IsprepaymentDelveryForm flag-----------------
                       lo_request->set_uri_path(
                    |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrderItem(SalesOrder='{ lv_so_number }',SalesOrderItem='{ lv_so_item }')| ).

                      lo_request->set_header_fields( VALUE #(
                        ( name = 'X-CSRF-Token' value = lv_csrf_token )
                        ( name = 'Accept'       value = 'application/json' )
                        ( name = 'Content-Type' value = 'application/json' )
                        ( name = 'Cookie'       value = lv_session )
                         ( name = 'If-Match'     value = '*' )
                      ) ).

                      "Create payload for PATCH d
                      DATA(lo_json_builder_flag2) = xco_cp_json=>data->builder( ).

                      lo_json_builder_flag2->begin_object( ).
                      lo_json_builder_flag2->add_member( 'YY1_ISPREPAYDELVFORM_SDI' )->add_string( 'N' ).

                      lo_json_builder_flag2->end_object( ).

                      lo_request_body = lo_json_builder_flag2->get_data( )->to_string( ).
                      lo_request->set_text( lo_request_body ).

                      lo_response = lo_http_client->execute( i_method = if_web_http_client=>patch ).
                      http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                      lo_request->delete_header_field( 'If-Match' ).

                       " -------------- END Update IsprepaymentDelveryForm flag-----------------
                ELSE.
                    " No remaining line -> after reverse 1 item need to add remaining line back
                    "Add new remaining amount line
                    "--- ADD Remainder Line ---
                         DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
                        DATA(lv_datenow)   = |{ lv_today+0(4) }-{ lv_today+4(2) }-{ lv_today+6(2) }T00:00:00|.
                      lo_request = lo_http_client->get_http_request( ).
                      lo_request->set_uri_path( |/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SlsOrderItemBillingPlanItem| ).

                      "Set CSRF + Cookie headers
                      lo_request->set_header_fields( VALUE #(
                        ( name = 'X-CSRF-Token' value = lv_csrf_token )
                        ( name = 'Accept'       value = 'application/json' )
                        ( name = 'Content-Type' value = 'application/json' )
                        ( name = 'Cookie'       value = lv_session )
                      ) ).

                      "Create payload for POST
                      DATA(lo_json_builder_7) = xco_cp_json=>data->builder( ).

                      lo_json_builder_7->begin_object( ).
                      lo_json_builder_7->add_member( 'SalesOrder' )->add_string( lv_so_number ).
                      lo_json_builder_7->add_member( 'SalesOrderItem' )->add_string( |{ lv_so_item }| ).
                      lo_json_builder_7->add_member( 'BillingPlan' )->add_string( lv_billing_plan ).
                      lo_json_builder_7->add_member( 'BillingPlanBillingDate' )->add_string( |{ lv_datenow }| ).
                      lo_json_builder_7->add_member( 'BillingPlanAmount' )->add_string( |{ lv_new_amt }| ).
                      lo_json_builder_7->add_member( 'BillingPlanDateDescriptionCode' )->add_string( 'Y008' ).
                      lo_json_builder_7->add_member( 'ProposedBillingDocumentType' )->add_string( 'F2' ).
                      lo_json_builder_7->add_member( 'BillingBlockReason' )->add_string( '' ).
                      lo_json_builder_7->add_member( 'BillingPlanDateCategory' )->add_string( '00' ).
                      lo_json_builder_7->end_object( ).

                      lo_request_body = lo_json_builder_7->get_data( )->to_string( ).
                      lo_request->set_text( lo_request_body ).


                      lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).


                      http_status = lv_status = lo_response->get_header_field( '~status_code' ).

                      "Debug
                      DATA(lv_body_debug8)   = lo_request->get_text( ).
                      DATA(lt_headers_debug8) = lo_request->get_header_fields( ).
                      DATA(lv_method_debug8) = lo_request->get_method( ).
                      DATA(lv_res_debug8) = lo_response->get_text( ).
                      DATA(lt_res_headers8) = lo_response->get_header_fields( ).
                      DATA(lv_path_debug8) = lo_request->get_header_field( i_name = '~request_uri' ).

                      "end debug
                ENDIF.
            ENDIF.

        ENDIF.


        "--- Build return structure ---
        DATA ls_type_result TYPE zi_Prepayment_Updates.
        ls_type_result-status = 'Success'.
        LOOP AT keys INTO DATA(ls_key_res).

          APPEND VALUE #( %tky = ls_key_res-%tky
                %param = CORRESPONDING #( ls_type_result ) ) TO result.

        ENDLOOP.
*        DATA(ls_result) = VALUE zi_Prepayment_Updates(
*                      status = '4900001234'
*                      ).
*
*          result = VALUE #( ( %tky   = keys[ 1 ]-%tky
*                              %param = ls_result ) ).
      CATCH cx_http_dest_provider_error
          cx_web_http_client_error INTO DATA(lo_http_error1).
        rv_result = |API1 failed: { lo_http_error1->get_text( ) }\n\n|.

      CATCH cx_root INTO DATA(lo_unexpected1).
        rv_result = |API1 unexpected error: { lo_unexpected1->get_text( ) }\n\n|.

    ENDTRY.
  ENDMETHOD.

ENDCLASS.
