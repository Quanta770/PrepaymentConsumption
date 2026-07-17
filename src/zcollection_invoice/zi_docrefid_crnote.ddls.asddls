@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document Reference ID for Credit Note'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_DOCREFID_CRNOTE
  as select distinct from I_JournalEntry  as Opp
    left outer join       ZR_CONFIG_VALUE as prefix on  prefix.Category    = Opp.CompanyCode
                                                    and prefix.ParameterID = 'CreditNotePfix'
    //updated 27/4/2026
    left outer join       ZR_CONFIG_VALUE as CN_DocType on  CN_DocType.Category    = Opp.CompanyCode
                                                    and CN_DocType.ParameterID = 'AccDocType_CR' 
//                                                    and Opp.AccountingDocumentType = CN_DocType.Value1 //updated 27/4/2026                                        
{
  key Opp.CompanyCode,
  key Opp.FiscalYear,
//  max(  Opp.DocumentReferenceID ) as DocumentReferenceID
  max(  case when Opp.AccountingDocumentType = CN_DocType.Value1 
  then Opp.DocumentReferenceID else '' end ) as DocumentReferenceID
} where  (left(Opp.DocumentReferenceID,2 ) = prefix.Value1 or Opp.DocumentReferenceID is initial) 
//and Opp.AccountingDocumentType = CN_DocType.Value1

group by
  Opp.CompanyCode,
  Opp.FiscalYear

  
