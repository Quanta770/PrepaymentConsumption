@EndUserText.label: 'Custom entity for Journal Entry posting'
@ObjectModel: {
    query: {
        implementedBy: 'ABAP:ZCL_FI_PREPAYJOURNAL_ENTRY'
    }
}
define custom entity ZI_PREPAYPOST_CUSTOM_ENT
 {
  key prepaymentrequest : abap.char(10);
  prepaymentso        : abap.char(10);
  prepaymentsoitem   : abap.char(6);
  prepaycurrency     : waers;
  salesorg          : abap.char(4);
  soldto            : abap.char(10);
  scenario          : abap.char(2);
  itemctgy          : abap.char(2);
  deliveryso         : abap.char(10);
  deliverysoitem     : abap.char(6);
  delvcurrency       : waers;
  @Semantics.amount.currencyCode : 'delvcurrency'
  amounttoapply       : abap.curr(23,2);
  profitcenter      : abap.char(10);
  wbs               : abap.char(24);
  AccountingDocument   : abap.char(10);
  Status             : abap.char(10);
  Remarks              : abap.char(512);
}
