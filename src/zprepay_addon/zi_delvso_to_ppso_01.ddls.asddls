
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'For Key user extensibility'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_DELVSO_TO_PPSO_01   as select from    ZI_CONSUMPTION_HIST_LATEST         as Delv
    left outer join ZI_CONSUMPTION_HIST_LATEST         as Ppay on  Delv.Prepaymentreqnumber = Ppay.Prepaymentreqnumber
                                                           and Delv.Sotype              = 'D'
                                                           and Ppay.Sotype              = 'P'
    left outer join ZI_Prepayment_CollectionStatus as Stat on  Stat.SalesDocument     = Ppay.Salesorder
                                                           and Stat.SalesDocumentItem = Ppay.Salesorderitem
    left outer join I_BillingDocumentItem as Billitem  on Billitem.SalesDocument =  Ppay.Salesorder
                                                      and Billitem.SalesDocumentItem =  Ppay.Salesorderitem
    left outer join I_BillingDocument as BillHdr  on BillHdr.BillingDocument =  Billitem.BillingDocument                                                  
{

  key Delv.Salesorder     as DeliverySO,
  key Delv.Salesorderitem as DeliverySOItem,
      Ppay.Salesorder     as PrepaySo,
      Ppay.Salesorderitem as PrepaySOItem,
      Stat.AccountingDocument,
      Stat.FiscalYear,
      BillHdr.BillingDocument as BillingDocument,
      BillHdr.YY1_EINV_CODE2_BDH as EinvCode


}
