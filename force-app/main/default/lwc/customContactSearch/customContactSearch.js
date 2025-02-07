import { LightningElement,api } from 'lwc';

export default class CustomContactSearch extends LightningElement {
  @api contactId;

    displayInfo = {
        primaryField: 'Name',
        additionalFields: ['Email'],
    };

    filter = {
        criteria: [
            {
                fieldPath: 'Email',
                operator: 'ne',
                value: '',
            }
        ],
        filterLogic: '1',
    };
    handleContactSelection(event) {        
        this.contactId=event.detail.recordId;        
    }
}