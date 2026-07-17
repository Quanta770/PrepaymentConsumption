CLASS lhc_ZI_PREPAY_STATUS_UPDATE DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_prepay_status_update RESULT result.

ENDCLASS.

CLASS lhc_ZI_PREPAY_STATUS_UPDATE IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

ENDCLASS.
