import { LightningElement, api, wire } from 'lwc';
import getFreeAvailableReservations from '@salesforce/apex/AAB_HoraryMananger.getFreeAvailableReservations';
import createReservationsFromJson from '@salesforce/apex/AAB_HoraryMananger.createReservationsFromJson';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class ShowAvailablesHoraries extends LightningElement {
    @api userId;
    @api dateString;
    @api contactId;
    @api centerId;
    @api serviceId;
    @api bookInformation;
    @api bookingId;
    @api availableActions = [];
    @api successMessage = '';  // Flow variable for success message
    @api errorMessage = '';    // Flow variable for error message
    availableReservations = [];

    @wire(getFreeAvailableReservations, { 
        userId: '$userId', 
        dateString: '$dateString', 
        contactId: '$contactId', 
        centerId: '$centerId', 
        serviceId: '$serviceId' 
    })
    eventObj(value) {
        const { data, error } = value;
        if (data) {
            let records = data.map(event => {
                const startDate = new Date(event.AAB_StartDateTime__c);
                const endDate = new Date(event.AAB_EndDateTime__c);
                const formattedDate = startDate.toLocaleString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
                const startTime = this.formatTime(startDate);
                const endTime = this.formatTime(endDate);
                const duration = (endDate - startDate) / (1000 * 60 * 60);  // duration in hours
                const key = `${formattedDate} ${startDate.toLocaleTimeString()} - ${endDate.toLocaleTimeString()} (${duration} hour${duration > 1 ? 's' : ''})`;
                return { 
                    ...event,
                    key: key
                };
            });
            this.availableReservations = JSON.parse(JSON.stringify(records));
            this.errorMessage = '';  // Clear error message if data exists
        } else if (error) {
            this.availableReservations = [];
            this.errorMessage = 'No available reservations found. Please check your filters or try again later.';  // Error message
        }
    }

    handleNext() { console.log('hm0');
        if (this.availableActions.find((action) => action === "NEXT")) {console.log('hm1');
            const navigateNextEvent = new FlowNavigationNextEvent();console.log('hm2');
            console.log('text'+this.bookingId);
            /*navigateNextEvent.setParams({
                newBookingId: this.bookingId  // Sending bookInformation to the next screen
            });*/
            console.log('hm3'+this.bookingId );
            this.dispatchEvent(navigateNextEvent);console.log('hm4');
        }
    }

    handleEvent(event) {
        var tmp = [...this.availableReservations];
        let task = tmp.find(x => x.key === event.target.label);

        if (task) {
           
            const clonedTask = JSON.parse(JSON.stringify(task));
            delete clonedTask.key;  // Remove key before sending data
            this.bookInformation = JSON.stringify(task);
            // Call createReservationsFromJson before navigating to the next step
            this.createReservations(clonedTask);
        }
    }

    // Helper function to format the time in AM/PM format
    formatTime(date) {
        const hours = date.getUTCHours();
        const minutes = date.getUTCMinutes();
        const ampm = hours >= 12 ? 'PM' : 'AM';
        const formattedHours = hours % 12 || 12;  // Convert to 12-hour format
        const formattedMinutes = minutes < 10 ? '0' + minutes : minutes;
        return `${formattedHours}:${formattedMinutes} ${ampm}`;
    }

    createReservations(task) {
        const jsonReservations = JSON.stringify([task]);  // Assuming task is a single reservation
        console.log(jsonReservations);

        createReservationsFromJson({ jsonString: jsonReservations })
            .then((response) => {
                console.log('Reservations created successfully');
                console.log('response'+response);
                this.bookingId=response;
                //this.successMessage = 'Reservations created successfully';  // Set success message in flow variable
                this.handleNext();  // Only navigate to the next step after successful creation
            })
            .catch((error) => {
                console.error('Error creating reservations:', error.body.message);
                this.errorMessage = 'Error creating reservations:'+error.body.message;  // Set error message in flow variable
            });
    }
}