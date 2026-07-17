define abstract entity ZI_PREVIEW_RESULT
{
  journalentry : abap.char(10);
  journalitem  : abap.char(6);
  salesorder   : abap.char(10);
  glaccount    : abap.char(10);
  accountname  : abap.char(30);
  @Semantics.amount.currencyCode : 'currencycd'
  debit        : abap.curr(23,2);
  @Semantics.amount.currencyCode : 'currencycd'
  credit       : abap.curr(23,2);
  currencycd   : abap.cuky;
  wbselement   : abap.char(24);
  writeoff     : abap.char(1);
}
