@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Get the latest Document Reference ID'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_DOCREFID_GET
  as select distinct from I_JournalEntry  as Opp
    inner join       ZR_CONFIG_VALUE as Inv_DocType on  Inv_DocType.Category    = Opp.CompanyCode
                                                    and Inv_DocType.ParameterID = 'AccDocType' 
                                                    and Opp.AccountingDocumentType = Inv_DocType.Value1 
    left outer join       ZR_CONFIG_VALUE as prefix on  prefix.Category    = Opp.CompanyCode
                                                    and prefix.ParameterID = 'InvoicePrefix'
{
  key Opp.CompanyCode,
  key Opp.FiscalYear,
      max(  Opp.DocumentReferenceID ) as DocumentReferenceID

}
where
     left(Opp.DocumentReferenceID,3 ) = prefix.Value1
  or Opp.DocumentReferenceID          is initial

group by
  Opp.CompanyCode,
  Opp.FiscalYear
