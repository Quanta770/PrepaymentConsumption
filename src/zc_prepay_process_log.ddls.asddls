@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment process log'
@Metadata.allowExtensions: true
@Search.searchable: true

@UI.presentationVariant: [{
  sortOrder: [{ by: 'LoggedAt', direction: #DESC }],
  visualizations: [{ type: #AS_LINEITEM }]
}]

@UI.headerInfo: {
  typeName: 'Log Entry',
  typeNamePlural: 'Log Entries',
  title:       { type: #STANDARD, value: 'DeliverySo' },
  description: { type: #STANDARD, value: 'DeliverySoItem' }
}

define root view entity ZC_PREPAY_PROCESS_LOG
  provider contract transactional_query
  as projection on ZI_PREPAY_PROCESS_LOG
{
      @UI.facet: [
        { id: 'StatusHeader', purpose: #HEADER, type: #DATAPOINT_REFERENCE,
          targetQualifier: 'StatusDP', position: 10 },
        { id: 'MsgHeader',    purpose: #HEADER, type: #DATAPOINT_REFERENCE,
          targetQualifier: 'MsgDP',    position: 20 },
        { id: 'General',   purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
          label: 'General',                position: 10 },
        { id: 'Reference', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
          label: 'SO Reference',           targetQualifier: 'Reference', position: 20 },
        { id: 'HttpStepTable', purpose: #STANDARD, type: #LINEITEM_REFERENCE,
          label: 'Billing Plan HTTP Steps', targetElement: '_ProcessStep', position: 30 },
        { id: 'JePosting', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
          label: 'JE Posting Result',      targetQualifier: 'JePosting', position: 40 }
      ]

      @UI.hidden: true
  key LogId,

      @EndUserText.label: 'Flow Type'
      @UI.lineItem:       [ { position: 10, importance: #HIGH } ]
      @UI.selectionField: [ { position: 10 } ]
      @UI.identification: [ { position: 10 } ]
      FlowType,

      @EndUserText.label: 'Logged At'
      @UI.lineItem:       [ { position: 20, importance: #HIGH } ]
      @UI.selectionField: [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
      LoggedAt,

      @EndUserText.label: 'Logged By'
      @UI.identification: [ { position: 30 } ]
      LoggedBy,

      @EndUserText.label: 'Status'
      @UI.lineItem:       [ { position: 30, criticality: 'StatusCriticality', importance: #HIGH } ]
      @UI.selectionField: [ { position: 30 } ]
      @UI.dataPoint:      { qualifier: 'StatusDP', title: 'Status', criticality: 'StatusCriticality' }
      @ObjectModel.text.element: ['StatusText']
      @UI.textArrangement: #TEXT_ONLY
      Status,

      @EndUserText.label: 'Message'
      @UI.lineItem:       [ { position: 40, importance: #HIGH } ]
      @UI.multiLineText: true
      @UI.dataPoint:      { qualifier: 'MsgDP', title: 'Message' }
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      MessageText,

      @EndUserText.label: 'Delivery SO'
      @UI.lineItem:       [ { position: 50, importance: #HIGH } ]
      @UI.selectionField: [ { position: 40 } ]
      @UI.fieldGroup:     [ { qualifier: 'Reference', position: 10 } ]
      @Search.defaultSearchElement: true
      DeliverySo,

      @EndUserText.label: 'Delivery SO Item'
      @UI.lineItem:       [ { position: 60, importance: #HIGH } ]
      @UI.fieldGroup:     [ { qualifier: 'Reference', position: 20 } ]
      DeliverySoItem,

      @EndUserText.label: 'Prepayment SO'
      @UI.selectionField: [ { position: 50 } ]
      @UI.fieldGroup:     [ { qualifier: 'Reference', position: 30 } ]
      PrepaymentSo,

      @EndUserText.label: 'Prepayment SO Item'
      @UI.fieldGroup:     [ { qualifier: 'Reference', position: 40 } ]
      PrepaymentSoItem,

      @EndUserText.label: 'Company Code'
      @UI.selectionField: [ { position: 60 } ]
      @UI.fieldGroup:     [ { qualifier: 'Reference', position: 50 } ]
      CompanyCode,

      @EndUserText.label: 'Accounting Document'
      @UI.lineItem:       [ { position: 90, importance: #MEDIUM } ]
      @UI.fieldGroup:     [ { qualifier: 'JePosting', position: 10 } ]
      AccountingDocument,

      @EndUserText.label: 'Fiscal Year'
      @UI.fieldGroup:     [ { qualifier: 'JePosting', position: 20 } ]
      FiscalYear,

      _ProcessStep : redirected to composition child ZC_PREPAY_PROCESS_STEP,

      @UI.hidden: true
      StatusCriticality,

      @UI.hidden: true
      StatusText
}
