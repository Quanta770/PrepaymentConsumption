@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'GEt Prepay SO details from Delv SO'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_DELIVSO_TO_PREPAYSO
  as select from    ZI_CONSUMPTION_HIST_LATEST     as Delv

    left outer join ZI_CONSUMPTION_HIST_LATEST     as Ppay     on  Delv.Prepaymentreqnumber = Ppay.Prepaymentreqnumber
                                                               and Delv.Sotype              = 'D'
                                                               and Ppay.Sotype              = 'P'

    left outer join ZI_PREPAYMENT_COLLECTIONSTATUS as Stat     on  Stat.SalesDocument     = Ppay.Salesorder
                                                               and Stat.SalesDocumentItem = Ppay.Salesorderitem

    left outer join I_BillingDocumentItem          as Billitem on  Billitem.SalesDocument     = Delv.Salesorder
                                                               and Billitem.SalesDocumentItem = Delv.Salesorderitem

    left outer join I_BillingDocument              as BillHdr  on BillHdr.BillingDocument = Billitem.BillingDocument
    
    inner join ZI_COLLECTION_INV_NUM as collection on collection.AccountingDocument = Stat.AccountingDocument
                                                        and collection.FiscalYear = Stat.FiscalYear
                                                        and collection.CompanyCode = Stat.CompanyCode
                                                        and (collection.AccountingDocumentType = 'D8' or collection.AccountingDocumentType = 'DZ') 
                                                        
{

  key Delv.Salesorder            as DeliverySO,
  key Delv.Salesorderitem        as DeliverySOItem,
      Ppay.Salesorder            as PrepaySo,
      Ppay.Salesorderitem        as PrepaySOItem,
      Stat.AccountingDocument,
      Stat.FiscalYear,
      Stat.Reference3IDByBusinessPartner,
      collection.CollectionInvoiceNumber as CollectionInvoiceNumber,
      Stat.BillingDocument as PrepayBillingDocument,
      BillHdr.BillingDocument    as BillingDocument,
      BillHdr.YY1_EINV_CODE2_BDH as EinvCode,
      cast(Ppay.Soamount as abap.dec(23,2)) as ConsumedAmount

} 
