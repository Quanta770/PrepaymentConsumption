CLASS lhc_OpenIOStaging DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR OpenIOStaging RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR OpenIOStaging RESULT result.

    METHODS deleteSessionRows FOR MODIFY
      IMPORTING keys FOR ACTION OpenIOStaging~deleteSessionRows RESULT result.

ENDCLASS.

CLASS lhc_OpenIOStaging IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.


"Delete all rows for a given sessionId and also rows older than 2 day to clean up old data.
  METHOD deleteSessionRows.
    " ── 1. Read sessionId from parameter ─────────────────────────────────────
    READ TABLE keys INTO DATA(ls_key) INDEX 1.

    IF sy-subrc <> 0 OR ls_key-%param-sessionid IS INITIAL.
      result = VALUE #( ( %param = VALUE #(
        processedCount = 0
        sessionId    = ||
        message      = 'sessionId parameter is required'
        hasErrors    = abap_true
      ) ) ).
      RETURN.
    ENDIF.

    DATA(lv_session_id) = ls_key-%param-sessionid.

    "Cutoff date time
    DATA(lv_cutoff) = cl_abap_context_info=>get_system_date( ) - 2.
   " ── 2. Select the keys of all rows belonging to this session ─────────────
      " Direct SQL SELECT is allowed — only DML (INSERT/UPDATE/DELETE) is blocked
      SELECT sap_uuid
        FROM ztb_openio_rows
        WHERE session_id = @lv_session_id
        OR created_on < @lv_cutoff
        INTO TABLE @DATA(lt_keys).

      IF lt_keys IS INITIAL.
        result = VALUE #( ( %param = VALUE #(
          processedCount = 0
          sessionId    = lv_session_id
          message      = |No rows found for sessionId { lv_session_id }|
          hasErrors    = abap_false
        ) ) ).
        RETURN.
      ENDIF.

      DATA(lv_count) = lines( lt_keys ).

      " ── 3. Build the delete keys table for MODIFY ENTITIES ───────────────────
      DATA lt_delete_keys TYPE TABLE FOR DELETE zi_openio_staging_rows.

      LOOP AT lt_keys INTO DATA(ls_key_row).
        APPEND VALUE #( %key-sapuuid = ls_key_row-sap_uuid )
          TO lt_delete_keys.
      ENDLOOP.

      " ── 4. Delete via RAP — IN LOCAL MODE skips auth/feature checks ──────────
      MODIFY ENTITIES OF zi_openio_staging_rows IN LOCAL MODE
        ENTITY OpenIOStaging
          DELETE FROM lt_delete_keys
        REPORTED DATA(lt_reported)
        FAILED  DATA(lt_failed).



      " ── 5. Check for failures ─────────────────────────────────────────────────
      DATA(lv_failed_count) = lines( lt_failed-OpenIOStaging ).
      DATA(lv_deleted)      = lv_count - lv_failed_count.

      result = VALUE #( (
        %key   = ls_key-%key
        %param = VALUE #(
          processedCount = lv_deleted
          sessionId    = lv_session_id
          message      = |{ lv_deleted } of { lv_count } rows deleted for session { lv_session_id }|
          hasErrors    = abap_false
        )
      ) ).
  ENDMETHOD.

ENDCLASS.
