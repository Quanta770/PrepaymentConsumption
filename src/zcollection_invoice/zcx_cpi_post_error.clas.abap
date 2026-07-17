CLASS zcx_cpi_post_error DEFINITION
  PUBLIC
  INHERITING FROM cx_no_check
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_dyn_msg.

    CONSTANTS:
      BEGIN OF csrf_fetch_failed,
        msgid TYPE symsgid    VALUE 'ZMC_CPI_POST_ERROR',
        msgno TYPE symsgno    VALUE '001',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF csrf_fetch_failed,

      BEGIN OF http_post_failed,
        msgid TYPE symsgid    VALUE 'ZMC_CPI_POST_ERROR',
        msgno TYPE symsgno    VALUE '002',
        attr1 TYPE scx_attrname VALUE 'MV_V1',
        attr2 TYPE scx_attrname VALUE 'MV_V2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF http_post_failed,

      BEGIN OF destination_error,
        msgid TYPE symsgid    VALUE 'ZMC_CPI_POST_ERROR',
        msgno TYPE symsgno    VALUE '003',
        attr1 TYPE scx_attrname VALUE 'MV_V1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF destination_error,

      BEGIN OF pdf_render_failed,
        msgid TYPE symsgid    VALUE 'ZMC_CPI_POST_ERROR',
        msgno TYPE symsgno    VALUE '004',
        attr1 TYPE scx_attrname VALUE 'MV_V1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pdf_render_failed.

    DATA mv_v1 TYPE string.
    DATA mv_v2 TYPE string.

    METHODS constructor
      IMPORTING
        textid   TYPE scx_t100key OPTIONAL
        previous LIKE previous                  OPTIONAL
        mv_v1    TYPE string                    OPTIONAL
        mv_v2    TYPE string                    OPTIONAL.

ENDCLASS.



CLASS ZCX_CPI_POST_ERROR IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor(
      previous = previous ).

    me->mv_v1 = mv_v1.
    me->mv_v2 = mv_v2.

    " Wire substitution variables into the interface —
    " these map to &1 and &2 in the message text
    if_t100_dyn_msg~msgv1 = CONV #( mv_v1 ).
    if_t100_dyn_msg~msgv2 = CONV #( mv_v2 ).

  ENDMETHOD.
ENDCLASS.
