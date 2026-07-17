@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery SO Header'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_Delivery_SO_Header as select from I_SalesDocument
{
    key SalesDocument as SalesDocument,
    SalesOrganization,
    SoldToParty,
    YY1_PrepaymentScenario_SDH as PrepaymentScenario,
    YY1_SFSOIOType_SDH ,
    YY1_SF_SO_BusinessUnit_SDH  as BusinessUnit,
    SalesDocumentDate as DocumentDate,
    DistributionChannel
}

where
YY1_PrepaymentScenario_SDH <> 'A'
and YY1_PrepaymentScenario_SDH <> 'B'
and YY1_PrepaymentScenario_SDH <> 'C'
and YY1_PrepaymentScenario_SDH <> 'D'
