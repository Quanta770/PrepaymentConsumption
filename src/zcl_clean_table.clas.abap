CLASS zcl_clean_table DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CLEAN_TABLE IMPLEMENTATION.


METHOD if_oo_adt_classrun~main.
*DATA: it_so_text type standard table of ztb_consume_hist.
*
*select * from ztb_consume_hist into table @it_so_text.
*
*    delete  ztb_consume_hist from table @it_so_text
select * from ztb_prepayment_c
 where 1 = 1
 into table @data(lt_prepay).

delete ztb_prepayment_c from table @lt_prepay.



endmethod.
ENDCLASS.
