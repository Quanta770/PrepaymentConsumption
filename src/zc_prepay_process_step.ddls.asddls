@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment log - HTTP step detail'
@Metadata.allowExtensions: true
define view entity ZC_PREPAY_PROCESS_STEP
  as projection on ZI_PREPAY_PROCESS_STEP
{
      @UI.hidden: true
  key LogId,

      @EndUserText.label: 'Correlation ID'
      @UI.identification: [ { position: 5 } ]
      @UI.lineItem: [ { position: 5 } ]
      CorrelationId,

      @EndUserText.label: 'Step Seq'
      @UI.identification: [ { position: 10 } ]
      @UI.lineItem: [ { position: 10 } ]
      StepSeq,

      @EndUserText.label: 'Step Name'
      @UI.identification: [ { position: 20 } ]
      @UI.lineItem: [ { position: 20 } ]
      StepName,

      @EndUserText.label: 'HTTP Method'
      @UI.identification: [ { position: 30 } ]
      @UI.lineItem: [ { position: 30 } ]
      HttpMethod,

      @EndUserText.label: 'HTTP Status'
      @UI.identification: [ { position: 40 } ]
      @UI.lineItem: [ { position: 40 } ]
      HttpStatus,

      @EndUserText.label: 'URI'
      @UI.identification: [ { position: 50 } ]
      @UI.lineItem: [ { position: 50 } ]
      Uri,

      @EndUserText.label: 'Response Body'
      @UI.identification: [ { position: 70 } ]
      @UI.lineItem: [ { position: 70 } ]
      @UI.multiLineText: true
      ResponseBody,

      _parent : redirected to parent ZC_PREPAY_PROCESS_LOG
}
