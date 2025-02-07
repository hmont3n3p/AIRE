public with sharing class AAB_CreateServiceBookingController {
    @AuraEnabled(cacheable=true)
    public static AAB_Reservation__c getReservation(Id reservationId) {
        return [SELECT Id, AAB_Contact__c, AAB_Center__c, AAB_Service__c, AAB_ReservationDate__c, AAB_ReservationStatus__c, AAB_StartDateTime__c, AAB_EndDateTime__c
                FROM AAB_Reservation__c 
                WHERE Id = :reservationId 
                LIMIT 1];
    }
    @AuraEnabled
    public static String confirmReservationAndCreateEvent(Id reservationId) {
        try {
            // Obtener la reserva
            AAB_Reservation__c reservation = [
                SELECT Id, Name, AAB_ReservationStatus__c, AAB_StartDateTime__c, 
                       AAB_EndDateTime__c, AAB_ReservationDate__c, AAB_Contact__c, 
                       AAB_Center__c, AAB_Service__c
                FROM AAB_Reservation__c 
                WHERE Id = :reservationId 
                LIMIT 1
            ];
    
            if (reservation == null) {
                throw new AuraHandledException('Reservation not found.');
            }
    
            // Obtener el centro asociado y su límite de reservas por hora
            AAB_Center__c center = [
                SELECT AAB_MaxReservationsPerHour__c 
                FROM AAB_Center__c 
                WHERE Id = :reservation.AAB_Center__c
                LIMIT 1
            ];
    
            if (center == null) {
                throw new AuraHandledException('Associated center not found.');
            }
    
            // Contar el número de reservas confirmadas en el mismo centro, fecha y rango horario
            Integer confirmedReservationsCount = [
                SELECT COUNT()                 
                FROM AAB_Reservation__c
                WHERE AAB_ReservationDate__c = :reservation.AAB_ReservationDate__c
                AND AAB_Center__c = :reservation.AAB_Center__c
                AND AAB_StartDateTime__c >= :reservation.AAB_StartDateTime__c 
                AND AAB_StartDateTime__c < :reservation.AAB_StartDateTime__c .addHours(1)
                AND AAB_ReservationStatus__c = 'Confirmada'
                AND IsDeleted = FALSE
            ];
    
            // Validar si se ha alcanzado el límite de reservas por hora para la fecha específica
            if (confirmedReservationsCount >= center.AAB_MaxReservationsPerHour__c) {
                throw new AuraHandledException('The maximum number of reservations per hour has been reached for this center on this date.');
            }
    
            // Actualizar el estado de la reserva
            reservation.AAB_ReservationStatus__c = 'Confirmada';
            update reservation;
    
            // Crear un nuevo evento basado en la reserva
            Event newEvent = new Event(
                Subject = 'Reservation Confirmed: ' + reservation.Name,
                StartDateTime = reservation.AAB_StartDateTime__c,
                EndDateTime = reservation.AAB_EndDateTime__c,
                WhoId = reservation.AAB_Contact__c, // Contacto relacionado
                WhatId = reservation.Id, // Relacionado con la reserva
                Location = reservation.AAB_Center__c, // Centro relacionado
                Description = 'Service: ' + reservation.AAB_Service__c
            );
    
            insert newEvent;
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
}