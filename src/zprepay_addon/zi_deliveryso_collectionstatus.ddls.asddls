@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DElivery SO collection Status'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_DeliverySO_CollectionStatus
  as select from    ZI_Delivery_SO_Header_Item

    left outer join I_JournalEntryItem     as _Z_JournalEntryItem on  ZI_Delivery_SO_Header_Item.SalesDocument     = _Z_JournalEntryItem.SalesDocument
                                                                     and ZI_Delivery_SO_Header_Item.SalesDocumentItem = _Z_JournalEntryItem.SalesDocumentItem
    left outer join I_OperationalAcctgDocItem as Opp                 on  Opp.CompanyCode                   = _Z_JournalEntryItem.CompanyCode
                                                                     and Opp.AccountingDocument            = _Z_JournalEntryItem.AccountingDocument
                                                                     and Opp.FiscalYear                    = _Z_JournalEntryItem.FiscalYear
                                                                     and Opp.Reference3IDByBusinessPartner is not initial
    left outer join ZR_CONFIG_VALUE           as config              on  config.Category      = _Z_JournalEntryItem.CompanyCode
                                                                     and config.ParameterID = 'AccDocType'



{
  key  ZI_Delivery_SO_Header_Item.SalesDocument          as SalesDocument,
  key  ZI_Delivery_SO_Header_Item.SalesDocumentItem      as SalesDocumentItem,
       // ZI_Delivery_SO_Header_Item.PrepaymentReqNumPrepayment,
       ZI_Delivery_SO_Header_Item.PrepaymentScenario,
       // ZI_Delivery_SO_Header_Item.InvoiceClearingStatus,
       //  ZI_Delivery_SO_Header_Item.ContractItemDownPaymentStatus,

       _Z_JournalEntryItem.AccountingDocument,
       _Z_JournalEntryItem.FiscalYear,
       _Z_JournalEntryItem.CompanyCode,
       _Z_JournalEntryItem.ReferenceDocument,

       case when Opp.Reference3IDByBusinessPartner is initial
       then Opp.Reference1IDByBusinessPartner
       else  case when left(Opp.Reference3IDByBusinessPartner,3) <> config.Value3
            then ''
            else
            Opp.Reference3IDByBusinessPartner end    end as Reference3IDByBusinessPartner
       

}
