@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Get the latest Collection Inv Number'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_COLLECTIONINV_LATEST as select from ZI_COLLECINV_NUM_UN
{
    key CompanyCode,
    key FiscalYear,
    max(DocumentReferenceID) as DocumentReferenceID
}

group by CompanyCode,FiscalYear
