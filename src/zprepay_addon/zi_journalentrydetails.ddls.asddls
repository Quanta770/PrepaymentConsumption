@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Journal Entry Hdr'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_JOURNALENTRYDETAILS as select from I_JournalEntry
 left outer join ZI_PREPAY_EINV as _Z_PREPAY_EINV
    on I_JournalEntry.AccountingDocument = _Z_PREPAY_EINV.Accountingdocument
    and I_JournalEntry.FiscalYear = _Z_PREPAY_EINV.Fiscalyear
    and I_JournalEntry.CompanyCode = _Z_PREPAY_EINV.Companycode
 
 left outer join ZI_JournalEntryTotal as _JournalEntryTotal
    on I_JournalEntry.AccountingDocument = _JournalEntryTotal.AccountingDocument
    and I_JournalEntry.FiscalYear = _JournalEntryTotal.FiscalYear
    and I_JournalEntry.CompanyCode = _JournalEntryTotal.CompanyCode
    
     left outer join ZI_CustomerAddress as _CustomerAddress
    on I_JournalEntry.AccountingDocument = _CustomerAddress.AccountingDocument
    and I_JournalEntry.FiscalYear = _CustomerAddress.FiscalYear
    and I_JournalEntry.CompanyCode = _CustomerAddress.CompanyCode
    
composition [1..*] of ZI_JOURNALENTRYITEMDETAILS as _JournalEntryItem
//composition [1..*] of ZI_I_TaxItem as _JournalEntryTaxItem
{
    key I_JournalEntry.AccountingDocument as AccountingDocument,
    key I_JournalEntry.CompanyCode as CompanyCode,
    key I_JournalEntry.FiscalYear as FiscalYear,
    
    I_JournalEntry.AccountingDocumentType as AccountingDocumentType,
    I_JournalEntry.DocumentDate as DocumentDate,
    I_JournalEntry.PostingDate as PostingDate,
    I_JournalEntry.AccountingDocumentHeaderText as AccountingDocumentHeaderText,
    I_JournalEntry.AccountingDocCreatedByUser as AccountingDocCreatedByUser,
    I_JournalEntry.AccountingDocumentCategory as AccountingDocumentCategory,
    
    I_JournalEntry.TaxReportingDate as TaxReportingDate,
    I_JournalEntry.TaxFulfillmentDate as TaxFulfillmentDate,
    I_JournalEntry.TaxIsCalculatedAutomatically as TaxIsCalculatedAutomatically,
    I_JournalEntry.AbsoluteExchangeRate as ExchangeRate,
    concat(
             cast(I_JournalEntry.FiscalPeriod as abap.char(2)), 
             cast(I_JournalEntry.FiscalYear as abap.char(4))
    ) as FiscalYearPeriod,
    
    concat(
             cast(I_JournalEntry.AccountingDocumentCreationDate  as abap.char(10)), 
             cast(I_JournalEntry.CreationTime  as abap.char(10))
    ) as CreatedOn,
    
    @Semantics.amount.currencyCode: 'CurrencyCode'
    _JournalEntryTotal.TotalDebitAmountInTransCrcy as TotalDebitAmountInTransCrcy,
    @Semantics.amount.currencyCode: 'CurrencyCode'
    _JournalEntryTotal.TotalCreditAmountInTransCrcy as TotalCreditAmountInTransCrcy,
    _JournalEntryTotal.CurrencyCode as CurrencyCode,
   
   
    _Z_PREPAY_EINV.Statuscode as Statuscode,
    _Z_PREPAY_EINV.Statusdescription as Statusdescription,
    _Z_PREPAY_EINV.Flaginvoicesent as FlagInvoiceSent,
    _Z_PREPAY_EINV.Flagsfupdated as FlagSFUpdated,
    _Z_PREPAY_EINV.salesforceid_i as SalesforceIdI,
    
    // customer address
    _CustomerAddress.Customer as Customer,    
    _CustomerAddress.CustomerName as CustomerName,
    _CustomerAddress.City as City,
    _CustomerAddress.Country as Country,
    _CustomerAddress.CustomerAddress as CustomerAddress,
    _CustomerAddress.PostalCode as PostalCode,
    _CustomerAddress.Region as Region,
    _CustomerAddress.District as District,
    _CustomerAddress.VATRegistration as VATRegistration,
    _CustomerAddress.StreetName as StreetName,
    
    _JournalEntryItem
   // _JournalEntryTaxItem // Make association public,
}
