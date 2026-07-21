CLASS zcl_prepay_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS start_process
      IMPORTING
        iv_flow_type          TYPE string
        iv_delivery_so        TYPE string OPTIONAL
        iv_delivery_so_item   TYPE string OPTIONAL
        iv_prepayment_so      TYPE string OPTIONAL
        iv_prepayment_so_item TYPE string OPTIONAL
        iv_company_code       TYPE string OPTIONAL
      RETURNING VALUE(rv_log_id) TYPE sysuuid_c32.

    CLASS-METHODS log_step
      IMPORTING
        iv_correlation_id TYPE sysuuid_c32
        iv_flow_type      TYPE string
        iv_step_seq       TYPE i
        iv_step_name      TYPE string
        iv_http_method    TYPE string OPTIONAL
        iv_http_status    TYPE string OPTIONAL
        iv_uri            TYPE string OPTIONAL
        iv_response_body  TYPE string OPTIONAL
        iv_is_error       TYPE abap_bool OPTIONAL.

    CLASS-METHODS finish_process
      IMPORTING
        iv_log_id              TYPE sysuuid_c32
        iv_status               TYPE string
        iv_message_text         TYPE string OPTIONAL
        iv_accounting_document  TYPE string OPTIONAL
        iv_fiscal_year          TYPE string OPTIONAL.

ENDCLASS.



CLASS ZCL_PREPAY_LOG IMPLEMENTATION.


  METHOD start_process.

    TRY.
        DATA(lv_log_id) = cl_uuid_factory=>create_system_uuid( )->create_uuid_c32( ).

        DATA ls_log TYPE ztb_prepay_log.
        ls_log-log_id             = lv_log_id.
        ls_log-correlation_id     = lv_log_id.
        ls_log-flow_type          = iv_flow_type.
        ls_log-status             = 'P'.
        ls_log-delivery_so        = iv_delivery_so.
        ls_log-delivery_so_item   = iv_delivery_so_item.
        ls_log-prepayment_so      = iv_prepayment_so.
        ls_log-prepayment_so_item = iv_prepayment_so_item.
        ls_log-company_code       = iv_company_code.

        GET TIME STAMP FIELD ls_log-logged_at.
        ls_log-logged_by = cl_abap_context_info=>get_user_technical_name( ).

        MODIFY ENTITIES OF zi_prepay_log_write
          ENTITY PrepayLogWrite
            CREATE FIELDS ( LogId CorrelationId FlowType Status DeliverySo DeliverySoItem
                             PrepaymentSo PrepaymentSoItem CompanyCode
                             LoggedAt LoggedBy )
            WITH VALUE #( ( %cid            = 'PREPAYLOGSTART'
                             LogId           = lv_log_id
                             CorrelationId   = lv_log_id
                             FlowType        = iv_flow_type
                             Status          = 'P'
                             DeliverySo      = iv_delivery_so
                             DeliverySoItem  = iv_delivery_so_item
                             PrepaymentSo    = iv_prepayment_so
                             PrepaymentSoItem = iv_prepayment_so_item
                             CompanyCode     = iv_company_code
                             LoggedAt        = ls_log-logged_at
                             LoggedBy        = cl_abap_context_info=>get_user_technical_name( ) ) )
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported).

        rv_log_id = lv_log_id.

      CATCH cx_root.
        " Logging must never break the actual business action.
    ENDTRY.

  ENDMETHOD.


    METHOD log_step.

    TRY.
        DATA ls_log TYPE ztb_prepay_log.

        ls_log-log_id         = cl_uuid_factory=>create_system_uuid( )->create_uuid_c32( ).
        ls_log-correlation_id = iv_correlation_id.
        ls_log-flow_type      = iv_flow_type.
        ls_log-step_seq       = iv_step_seq.

        ls_log-step_name   = substring( val = iv_step_name   off = 0
                                len = nmin( val1 = strlen( iv_step_name )   val2 = 30 ) ).
        ls_log-http_method = substring( val = iv_http_method off = 0
                                len = nmin( val1 = strlen( iv_http_method ) val2 = 7 ) ).
        ls_log-http_status = substring( val = iv_http_status off = 0
                                len = nmin( val1 = strlen( iv_http_status ) val2 = 3 ) ).
        ls_log-uri = substring( val = iv_uri off = 0
                                len = nmin( val1 = strlen( iv_uri ) val2 = 1333 ) ).

        " A step is a failure if the caller says so explicitly (iv_is_error -
        " used for non-HTTP checks like SELECTs/validations that have no status
        " code at all), otherwise fall back to the HTTP status range when one
        " was actually supplied. No status and no explicit flag = treated as
        " a normal, successful checkpoint.
        DATA(lv_step_failed) = COND abap_bool(
          WHEN iv_is_error = abap_true THEN abap_true
          WHEN iv_http_status IS NOT INITIAL
            THEN xsdbool( CONV i( iv_http_status ) < 200 OR CONV i( iv_http_status ) >= 300 )
          ELSE abap_false ).

        " Only persist the response/detail body when the step actually failed -
        " on the (common) success path there's nothing worth keeping in it,
        " and it's the single largest/most sensitive field in this table.
        IF lv_step_failed = abap_true.
          ls_log-response_body = substring( val = iv_response_body off = 0
                                  len = nmin( val1 = strlen( iv_response_body ) val2 = 1333 ) ).
        ENDIF.

        GET TIME STAMP FIELD ls_log-logged_at.
        MODIFY ENTITIES OF zi_prepay_log_write
          ENTITY PrepayLogWrite
            CREATE FIELDS ( LogId CorrelationId FlowType StepSeq StepName HttpMethod
                             HttpStatus Uri ResponseBody LoggedAt LoggedBy )
            WITH VALUE #( ( %cid           = 'PREPAYLOGSTEP'
                             LogId          = ls_log-log_id
                             CorrelationId  = iv_correlation_id
                             FlowType       = iv_flow_type
                             StepSeq        = iv_step_seq
                             StepName       = ls_log-step_name
                             HttpMethod     = ls_log-http_method
                             HttpStatus     = ls_log-http_status
                             Uri            = ls_log-uri
                             ResponseBody   = ls_log-response_body
                             LoggedAt       = ls_log-logged_at
                             LoggedBy       = cl_abap_context_info=>get_user_technical_name( ) ) )
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported).
      CATCH cx_root.
        " Logging must never break the actual business action.
    ENDTRY.

  ENDMETHOD.


  METHOD finish_process.

    TRY.
        DATA(lv_message) = substring( val = iv_message_text off = 0
                              len = nmin( val1 = strlen( iv_message_text ) val2 = 1000 ) ).

       MODIFY ENTITIES OF zi_prepay_log_write
          ENTITY PrepayLogWrite
            UPDATE FIELDS ( Status MessageText AccountingDocument FiscalYear )
            WITH VALUE #( ( LogId              = iv_log_id
                             Status             = iv_status
                             MessageText        = lv_message
                             AccountingDocument = iv_accounting_document
                             FiscalYear         = iv_fiscal_year ) )
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported).

      CATCH cx_root.
        " Logging must never break the actual business action.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
