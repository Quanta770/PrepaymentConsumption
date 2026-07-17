CLASS zcl_generate_pdf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_pdf_result,
             pdf_content TYPE xstring,
             mime_type   TYPE string,
             file_name   TYPE string,
             error_text  TYPE string,
           END OF ty_pdf_result.

    CLASS-METHODS render_pdf
      IMPORTING
        iv_accounting_document TYPE belnr_d
        iv_company_code        TYPE bukrs
        iv_fiscal_year         TYPE gjahr
      RETURNING
        VALUE(rs_result)       TYPE ty_pdf_result.
ENDCLASS.



CLASS ZCL_GENERATE_PDF IMPLEMENTATION.


  METHOD render_pdf.
    TRY.
        DATA(lo_fdp_api) = cl_fp_fdp_services=>get_instance( 'ZSD_FDP_SAP09' ).
        DATA(lt_keys)    = lo_fdp_api->get_keys( ).

        lt_keys[ name = 'ACCOUNTINGDOCUMENT' ]-value = iv_accounting_document.
        lt_keys[ name = 'COMPANYCODE' ]-value         = iv_company_code.
        lt_keys[ name = 'FISCALYEAR' ]-value           = iv_fiscal_year.

        DATA(lv_xml_data) = lo_fdp_api->read_to_xml_v2( lt_keys ).

        DATA(lo_form_reader) = cl_fp_form_reader=>create_form_reader( 'ZFORM_SAP09' ).
        DATA(lv_xdp_layout)  = lo_form_reader->get_layout( ).

        cl_fp_ads_util=>render_pdf(
          EXPORTING
            iv_xml_data   = lv_xml_data
            iv_xdp_layout = lv_xdp_layout
            iv_locale     = 'en_US'
          IMPORTING
            ev_pdf        = rs_result-pdf_content
        ).

        rs_result-mime_type = 'application/pdf'.
        rs_result-file_name = |Form_Document_{ iv_accounting_document }.pdf|.

      CATCH cx_root INTO DATA(lx_root).
        rs_result-error_text = lx_root->get_longtext( ).
        CLEAR rs_result-pdf_content.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
