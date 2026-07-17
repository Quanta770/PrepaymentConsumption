@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Journal Entry Item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_JOURNALENTRYITEMDETAILS as select from I_JournalEntryItem
 left outer join  I_Customer as _Customer
    on I_JournalEntryItem.Customer = _Customer.Customer

association to parent ZI_JOURNALENTRYDETAILS  as _JournalEntryHdr
    on $projection.AccountingDocument = _JournalEntryHdr.AccountingDocument
    and $projection.FiscalYear = _JournalEntryHdr.FiscalYear
    and $projection.CompanyCode = _JournalEntryHdr.CompanyCode

{
    key I_JournalEntryItem.AccountingDocument,
    key I_JournalEntryItem.FiscalYear,
    key I_JournalEntryItem.CompanyCode,
    
       
    // Fields for Invoicing and accounting information
    I_JournalEntryItem.YY1_GUINo_JEI as GUINo,
    I_JournalEntryItem.YY1_AUTHORIZATION_NO_JEI as AuthorizationNo,
    I_JournalEntryItem.ReferenceDocument as ReferenceDocument,
    I_JournalEntryItem.ReferenceDocumentType as ReferenceDocumentType,
    I_JournalEntryItem.LedgerGLLineItem as LedgerGLLineItem,
    I_JournalEntryItem.Ledger as Ledger,
    
    // Fields for transaction amounts and currencies   
    @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
    abs(I_JournalEntryItem.AmountInCompanyCodeCurrency) as AmountInCompanyCodeCurrency,
     @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
    abs(I_JournalEntryItem.AmountInBalanceTransacCrcy) as AmountInBalanceTransacCrcy,
    I_JournalEntryItem.CompanyCodeCurrency as CompanyCodeCurrency,
    I_JournalEntryItem.GLAccount as GLAccount,
    I_JournalEntryItem.DebitCreditCode as DebitCreditCode,  
    I_JournalEntryItem.TransactionCurrency as CurrencyCode,
    
    I_JournalEntryItem.YY1_SALESFORCEID_I_JEI as SalesforceId,
    
    I_JournalEntryItem.SalesDocument as SalesDocument,
    I_JournalEntryItem.SalesDocumentItem as SalesDocumentItem,
    I_JournalEntryItem.AccountingDocumentItem as AccountingDocumentItem,
    I_JournalEntryItem.AccountingDocumentType, 
    @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
    cast(
      abs(
        case I_JournalEntryItem.DebitCreditCode
          when 'S' then cast( I_JournalEntryItem.AmountInCompanyCodeCurrency as abap.dec(23,2) )
          else 0
        end
      ) as abap.curr(23,2)
    ) as DebitAmountInCoCodeCrcy,

    @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
    cast(
      abs(
        case I_JournalEntryItem.DebitCreditCode
          when 'H' then cast(I_JournalEntryItem.AmountInCompanyCodeCurrency as abap.dec(23,2))
          else 0
        end
      ) as abap.curr(23,2)
    ) as CreditAmountInCoCodeCrcy,
    
    @Semantics.amount.currencyCode: 'CurrencyCode'
    cast(
      abs(
        case I_JournalEntryItem.DebitCreditCode
          when 'S' then cast(I_JournalEntryItem.AmountInTransactionCurrency as abap.dec(23,2))
          else 0
        end
      ) as abap.curr(23,2)
    ) as DebitAmountInTransCrcy,
    
    @Semantics.amount.currencyCode: 'CurrencyCode'
    cast(
      abs(
        case I_JournalEntryItem.DebitCreditCode
          when 'H' then cast(I_JournalEntryItem.AmountInTransactionCurrency as abap.dec(23,2))
          else 0
        end
      ) as abap.curr(23,2)
    ) as CreditAmountInTransCrcy,
    // Tax fields to be used in the UI (Taxes (1))  
//    @Semantics.amount.currencyCode: 'TaxCompanyCodeCurrency'
//    _OperationalAcctgDocTaxItem.TaxBaseAmountInCoCodeCrcy as TaxBaseAmountInCoCodeCrcy,
//    @Semantics.amount.currencyCode: 'TaxCompanyCodeCurrency'
//    _OperationalAcctgDocTaxItem.TaxAmountInCoCodeCrcy as TaxAmountInCoCodeCrcy,
//    _OperationalAcctgDocTaxItem.TaxDebitCreditCode as TaxDebitCreditCode,
//    _OperationalAcctgDocTaxItem.CompanyCodeCurrency as TaxCompanyCodeCurrency,
//    
//    @Semantics.amount.currencyCode: 'TaxCompanyCodeCurrency'
//    case _OperationalAcctgDocTaxItem.TaxDebitCreditCode when 'S' then _OperationalAcctgDocTaxItem.TaxAmountInCoCodeCrcy 
//    else cast(0.00 as abap.curr( 23,2 )) end 
//    as DebitTaxAmount,
//
//    @Semantics.amount.currencyCode: 'TaxCompanyCodeCurrency'
//    case _OperationalAcctgDocTaxItem.TaxDebitCreditCode when 'H' then _OperationalAcctgDocTaxItem.TaxAmountInCoCodeCrcy 
//    else cast(0.00 as abap.curr( 23,2 )) end
//    as CreditTaxAmount,
        
   _JournalEntryHdr // Make association public
} 
//where
//I_JournalEntryItem.Ledger = '0L'
//and I_JournalEntryItem.AccountingDocumentType =  case when I_JournalEntryItem.CompanyCode = 'HRH1'
//                                                  then 'D8'
//                                                 else 'DZ' end
where
  I_JournalEntryItem.Ledger = '0L'
  and (
        I_JournalEntryItem.AccountingDocumentType = 'D8'
     or I_JournalEntryItem.AccountingDocumentType = 'DZ'
     or I_JournalEntryItem.AccountingDocumentType = 'D9'      )
and I_JournalEntryItem.Customer is not initial
and I_JournalEntryItem.SpecialGLCode is not initial

