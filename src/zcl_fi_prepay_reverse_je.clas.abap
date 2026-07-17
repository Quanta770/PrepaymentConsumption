CLASS zcl_fi_prepay_reverse_je DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
    INTERFACES if_rap_query_provider.
    DATA: gt_entry1 TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
          lt_entry  LIKE LINE OF gt_entry1.
    TYPES: ty_je_create_line TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
           ty_glitem         TYPE LINE OF ty_je_create_line.
    TYPES: gty_je     TYPE TABLE FOR REPORTED LATE i_journalentrytp,
           gty_result TYPE STANDARD TABLE OF zi_prepay_reverse_custent.
    METHODS PrepayReverseje
      IMPORTING it_filters     TYPE if_rap_query_filter=>tt_name_range_pairs OPTIONAL
      RETURNING VALUE(rt_data) TYPE gty_je.
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA: gt_posted TYPE gty_je,
          gt_entry  TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
          gt_return TYPE STANDARD TABLE OF zi_prepay_reverse_custent.
ENDCLASS.



CLASS ZCL_FI_PREPAY_REVERSE_JE IMPLEMENTATION.


   METHOD if_oo_adt_classrun~main.

    DATA lt_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    DATA(lt_result) = PrepayReverseje( it_filters = lt_ranges ).
    IF gt_return IS NOT INITIAL.
      out->write( gt_return ).
    ELSE.
      out->write( lt_result ).
    ENDIF.

   ENDMETHOD.


  METHOD PrepayReverseje.
   DATA:  ls_entry  LIKE LINE OF gt_entry,
          lv_itemno TYPE n LENGTH 6.
    DATA: lt_entry TYPE TABLE FOR ACTION IMPORT i_journalentrytp~Reverse,
          lo_msg   TYPE REF TO if_abap_behv_message.
    DATA: gv_date  TYPE d,
          gv_time  TYPE t,
          lv_glacc TYPE saknr.
* Read the filters
    DATA(lv_AccDoc) = VALUE #( it_filters[ name = 'ACCOUNTINGDOCUMENT' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_CompanyCode) = VALUE #( it_filters[ name = 'COMPANYCODE' ]-range[ 1 ]-low OPTIONAL ).
    DATA(lv_FiscalYear) = VALUE #( it_filters[ name = 'FISCALYEAR' ]-range[ 1 ]-low OPTIONAL ).
*    data(lv_date) = cl_abap_context_info=>get_system_date( ).
    data(lv_date) = VALUE #( it_filters[ name = 'POSTDATE' ]-range[ 1 ]-low OPTIONAL ).
    data(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

     ls_entry-AccountingDocument  = lv_AccDoc.
     ls_entry-CompanyCode =   lv_CompanyCode.
     ls_entry-FiscalYear =   lv_FiscalYear.
     ls_entry-%param = value #( PostingDate = lv_date "sy-datlo
                                ReversalReason = '01'
                                CreatedByUser = lv_user )   .
     append ls_entry to gt_entry.
* Post Journal Entry
  IF gt_entry IS NOT INITIAL.
      MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
        ENTITY journalentry
        EXECUTE reverse FROM gt_entry
        MAPPED FINAL(ls_post_mapped)
        FAILED FINAL(ls_post_failed)
        REPORTED FINAL(ls_post_reported).
      IF sy-subrc = 0.
        IF ls_post_failed IS NOT INITIAL.
          CLEAR gt_return.
         LOOP AT ls_post_reported-journalentry INTO DATA(ls_report).
            lo_msg = ls_report-%msg.
            lv_itemno = lv_itemno + 1.
            DATA(lv_longtext) = lo_msg->if_message~get_longtext(  ).

            gt_return = VALUE #(  BASE gt_return (

            AccountingDocument   = lv_accdoc
            CompanyCode = lv_companycode
            FiscalYear = lv_fiscalyear
            Remarks      =    lv_longtext
            ) ).

          ENDLOOP.
          ELSE.
          COMMIT ENTITIES BEGIN
          RESPONSE OF i_journalentrytp
          FAILED DATA(lt_commit_failed)
          REPORTED DATA(lt_commit_reported).

          COMMIT ENTITIES END.
            rt_data = lt_commit_reported-journalentry.
          LOOP AT lt_commit_reported-journalentry INTO DATA(ls_je).
            lv_itemno = lv_itemno + 1.
            ENDLOOP.

        ENDIF.
      ELSE.
       RETURN.
      ENDIF.
  ENDIF.

  ENDMETHOD.


 METHOD if_rap_query_provider~select.

    DATA: gt_result TYPE STANDARD TABLE OF zi_prepay_reverse_custent.

    DATA(top)     = io_request->get_paging( )->get_page_size( ).
    DATA(skip)    = io_request->get_paging( )->get_offset( ).
    DATA(requested_fields)  = io_request->get_requested_elements( ).
    DATA(sort_order)    = io_request->get_sort_elements( ).

    TRY.

        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).


        gt_posted = PrepayReverseje( it_filters = lt_ranges ).
        IF gt_posted IS NOT INITIAL.
          LOOP AT gt_posted INTO DATA(ls_posted).

            gt_result = VALUE #(  BASE gt_result (
                accountingdocument = ls_posted-AccountingDocument
                companycode = ls_posted-CompanyCode
                fiscalyear = ls_posted-FiscalYear

            ) ).
          ENDLOOP.

        ELSE.
          gt_result = VALUE #(  BASE gt_result (
                remarks = VALUE #( gt_return[ 1 ]-remarks OPTIONAL )
            ) ).
        ENDIF.
        io_response->set_data( gt_result ).

        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( gt_result ) ).
        ENDIF.
      CATCH cx_root INTO DATA(exception).
        DATA(lv_exception_message) = cl_message_helper=>get_latest_t100_exception( exception )->if_message~get_longtext( ).
    ENDTRY.


  ENDMETHOD.
ENDCLASS.
