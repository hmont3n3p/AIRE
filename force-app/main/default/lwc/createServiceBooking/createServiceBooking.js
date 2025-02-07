import { LightningElement, api, wire } from 'lwc';
import getReservation from '@salesforce/apex/AAB_CreateServiceBookingController.getReservation';
import { refreshApex } from '@salesforce/apex';
import confirmReservationAndCreateEvent from '@salesforce/apex/AAB_CreateServiceBookingController.confirmReservationAndCreateEvent';

export default class ReservationDetails extends LightningElement {
    @api inProgressReservationId;
    @api flowResult;  // This will capture the result for Flow notification output
    @api availableActions = [];
    contactRecordId;
    centerRecordId;
    serviceRecordId;
    wiredReservationResult;
    
    showModal = false;  // Control modal visibility
    modalMessage = '';  // Message to display in the modal
    modalVariant = '';  // Type of message (Success/Error)
    modalIcon = ''; // Icon name for success or error

    // Fetch reservation data and extract necessary IDs
    @wire(getReservation, { reservationId: '$inProgressReservationId' })
    wiredReservation(result) {
        this.wiredReservationResult = result;
        if (result.data) {
            this.contactRecordId = result.data.AAB_Contact__c;
            this.centerRecordId = result.data.AAB_Center__c;
            this.serviceRecordId = result.data.AAB_Service__c;
        } else if (result.error) {
            console.error('Error fetching reservation', result.error);
        }
    }

    // Ensures data refresh when component is reloaded
    connectedCallback() {
        if (this.inProgressReservationId) {
            refreshApex(this.wiredReservationResult);
        }
    }

    handleReserveNow() {
        if (!this.inProgressReservationId) {     
            this.showModalWithMessage('Error', 'No reservation selected.', 'error');
            return;
        }

        confirmReservationAndCreateEvent({ reservationId: this.inProgressReservationId })
            .then((result) => {
                if (result === 'Success') {
                    this.showModalWithMessage('Success', 'Reservation confirmed and event created.', 'success');
                    return refreshApex(this.wiredReservationResult);
                } else {
                    this.showModalWithMessage('Error', 'Unexpected response from server.', 'error');
                    throw new Error('Unexpected response from server.');
                }
            })
            .then(() => {
                console.log('UI refreshed successfully.');
            })
            .catch((error) => {
                console.error('Error confirming reservation:', error);
                this.showModalWithMessage('Error', 'Failed to confirm reservation. Please try again later.', 'error');
            });
    }

    showModalWithMessage(title, message, variant) {
        this.modalMessage = message;
        this.modalVariant = variant;
        this.modalIcon = variant === 'success' ? 'utility:check' : 'utility:error';
        this.showModal = true;
    }

    handleNext() {
        if (this.availableActions.find((action) => action === "NEXT")) {
            const navigateNextEvent = new FlowNavigationNextEvent();           
            this.dispatchEvent(navigateNextEvent);
        }
    }

    // Close the modal and reset flow
    closeModal() {
        this.showModal = false;        
        if (this.modalVariant === 'success') {
            this.handleNext();
        }
    }
    get disableButton(){
        return (this.modalVariant === 'success');
    }
}