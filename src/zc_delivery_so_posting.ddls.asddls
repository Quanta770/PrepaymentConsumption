@EndUserText.label: 'Custom Entity for Journal Posting'
@ObjectModel: {
    query: {
        implementedBy: 'ABAP:ZCL_JOURNALENTRY_PREPAYMENT'
    }
}
define custom entity ZC_DELIVERY_SO_POSTING 
{
  key  DelvSoSalesDocument : abap.char(10);
  key  DelvSoSalesDocumentItem : abap.char(6);
  AccountingDocument : abap.char(10);
  CompanyCode   : abap.char(10);
  FiscalYear :abap.char(4);
    
}
