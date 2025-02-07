public class AAB_HoraryMananger {

// Método para insertar reservas en la base de datos a partir de un JSON string de reservas
@AuraEnabled
public static String createReservationsFromJson(String jsonString) {
    // Parse the JSON string into a list of AAB_Reservation__c objects
    List<AAB_Reservation__c> reservations = (List<AAB_Reservation__c>) JSON.deserialize(jsonString, List<AAB_Reservation__c>.class);

    // Ensure we have reservations to insert
    if (reservations != null && !reservations.isEmpty()) {
        // Map to store the max reservations per hour for each center
        Map<Id, Decimal> centerMaxReservationsPerHour = new Map<Id, Decimal>();

        // List to hold the reservations to be inserted
        List<AAB_Reservation__c> reservationsToInsert = new List<AAB_Reservation__c>();

        // Set to store the existing reservation times (for duplicate check)
        Set<String> existingReservationTimes = new Set<String>();

        // Step 1: Query the MaxReservationsPerHour for each center in the reservations
        Set<Id> centerIds = new Set<Id>();
        for (AAB_Reservation__c reservation : reservations) {
            centerIds.add(reservation.AAB_Center__c);
        }

        // Query all centers related to the reservations
        List<AAB_Center__c> centers = [
            SELECT Id, Name, AAB_CenterName__c,AAB_MaxReservationsPerHour__c 
            FROM AAB_Center__c 
            WHERE Id IN :centerIds
        ];

        // Fill the map with the max reservations per hour for each center
        Map<Id, AAB_Center__c> centerMap = new Map<Id, AAB_Center__c>();
        for (AAB_Center__c center : centers) {
            centerMaxReservationsPerHour.put(center.Id, center.AAB_MaxReservationsPerHour__c);
            centerMap.put(center.Id, center);  // Map to get center details for error formatting
        }

        // Step 2: Check for the maximum number of reservations for each center and each hour
        for (AAB_Reservation__c reservation : reservations) {
            Id centerId = reservation.AAB_Center__c;
            Date reservationDate = reservation.AAB_ReservationDate__c;
            DateTime reservationStartTime = reservation.AAB_StartDateTime__c;
            DateTime reservationEndTime = reservation.AAB_EndDateTime__c;
            Integer reservationHour = reservationStartTime.hour();

            // Get the max reservations per hour for this center
            Decimal maxReservationsPerHour = centerMaxReservationsPerHour.get(centerId);
            AAB_Center__c center = centerMap.get(centerId);

            // Step 2.1: Check the number of existing reservations for this center and hour
            Integer existingReservationsCount = [
                SELECT COUNT()
                FROM AAB_Reservation__c
                WHERE AAB_ReservationDate__c = :reservationDate
                AND AAB_Center__c = :centerId
                AND AAB_StartDateTime__c >= :reservationStartTime
                AND AAB_StartDateTime__c < :reservationStartTime.addHours(1)
                AND IsDeleted = FALSE
            ];

            if (existingReservationsCount >= maxReservationsPerHour) {
                throw new AuraHandledException('Maximum number of reservations reached for center: ' 
                    + center.AAB_CenterName__c 
                    + ' at ' + reservationStartTime.format() 
                    + ' (Start Time) - ' + reservationEndTime.format() + ' (End Time)');
            }

            // Step 2.2: Check for duplicate reservation times (same start time)
            if (existingReservationTimes.contains(reservationStartTime.format())) {
                throw new AuraHandledException('A reservation already exists for this time: ' 
                    + reservationStartTime.format() 
                    + ' on date: ' + reservationDate.format() 
                    + ' at center: ' + center.AAB_CenterName__c);
            } else {
                // Add the reservation to the list to be inserted
                reservationsToInsert.add(reservation);
                existingReservationTimes.add(reservationStartTime.format());
            }
        }

        // Step 3: Insert the valid reservations
        if (!reservationsToInsert.isEmpty()) {
            try {
                // Insert reservations into the database
                insert reservationsToInsert;
                return reservationsToInsert.get(0).Id;
            } catch (DmlException e) {
                // Handle any errors that occur during the insert process
                System.debug('Error inserting reservations: ' + e.getMessage());
                throw new AuraHandledException('Error inserting reservations. Please try again later or contact support.\nError: ' + e.getMessage());
            }
        } else {
            throw new AuraHandledException('No valid reservations to insert. Please ensure all details are correct and try again.');
        }
    } else {
        throw new AuraHandledException('No valid reservations found to insert. Please check the provided reservation data.');
    }
}

    // Método para obtener reservas disponibles para un usuario, contacto y fecha de 7 AM a 8 PM
    @AuraEnabled(cacheable=true)
    public static List<AAB_Reservation__c> getFreeAvailableReservations(String userId, String dateString, String contactId,String centerId,String serviceId) {
        Date selectedDate = Date.valueOf(dateString);
        TimeZone userTimeZone = UserInfo.getTimeZone();
        DateTime startOfDay = DateTime.newInstance(selectedDate, Time.newInstance(7, 0, 0, 0));
        startOfDay = startOfDay.addMinutes(userTimeZone.getOffset(startOfDay) / 60000);
        DateTime endOfDay = DateTime.newInstance(selectedDate, Time.newInstance(20, 0, 0, 0));
        endOfDay = endOfDay.addMinutes(userTimeZone.getOffset(endOfDay) / 60000);

        List<AAB_Reservation__c> existingReservations = [
            SELECT Id, AAB_StartDateTime__c, AAB_EndDateTime__c, OwnerId, AAB_Contact__c, AAB_ReservationStatus__c, IsDeleted, AAB_Center__c
            FROM AAB_Reservation__c
            WHERE OwnerId = :userId
            AND AAB_Contact__c = :contactId
            AND AAB_StartDateTime__c >= :startOfDay
            AND AAB_EndDateTime__c <= :endOfDay
            AND IsDeleted = FALSE
        ];

        Set<DateTime> bookedTimes = new Set<DateTime>();
        for (AAB_Reservation__c res : existingReservations) {
            bookedTimes.add(res.AAB_StartDateTime__c);
        }

        List<AAB_Reservation__c> availableReservations = new List<AAB_Reservation__c>();
        for (Integer hour = 7; hour < 20; hour++) {
            DateTime checkTime = DateTime.newInstance(selectedDate, Time.newInstance(hour, 0, 0, 0));
            checkTime = checkTime.addMinutes(userTimeZone.getOffset(checkTime) / 60000);

            if (!bookedTimes.contains(checkTime)) {
                AAB_Reservation__c availableReservation = new AAB_Reservation__c(
                    AAB_StartDateTime__c = checkTime,
                    AAB_EndDateTime__c = checkTime.addHours(1),
                    OwnerId = userId,
                    AAB_Contact__c = contactId,
                    AAB_Center__c=centerId,
                    AAB_Service__c=serviceId,
                    AAB_ReservationStatus__c = 'Pendiente',
                    AAB_ReservationDate__c = selectedDate
                );
                availableReservations.add(availableReservation);
            }
        }

        return availableReservations;
    }
}