@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment SO Header'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_Prepayment_SO_Header as select from I_SalesDocument
{
    key SalesDocument as SalesDocument,
    SalesOrganization,
    SoldToParty,
    YY1_PrepaymentScenario_SDH as PrepaymentScenario,
    YY1_SF_SO_BusinessUnit_SDH  as BusinessUnit,
    SalesDocumentDate as DocumentDate,
    DistributionChannel
}

where
YY1_PrepaymentScenario_SDH is not null
and YY1_PrepaymentScenario_SDH <> ''
and YY1_PrepaymentScenario_SDH is not initial
