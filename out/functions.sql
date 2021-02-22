create or replace  function departure(date_of_departure DATE)returns TABLE(
    destination VARCHAR(256), --kierunek samolotu (z KRK - do )
    flight_id VARCHAR(256), --id lotu
    departure_time TIME  --godzina wylotu
)

as
$$
begin
    return query
    select A.city, F.id, F.departure_time
    FROM flights as F JOIN connections as CO ON F.connection = CO.id
        JOIN Docks as D on Co.departure_dock = D.id
        JOIN Airports AS A ON D.airport = A.id
    WHERE F.departure_date = date_of_departure and A.city = 'Cracow';
end;
$$
LANGUAGE 'plpgsql'

SELECT * FROM departure('1979-08-26');

create or replace  function arrival(date_of_arrival DATE)returns TABLE(
    from_where VARCHAR(256), --skad przylecial samolot (z .. - do KRK )
    flight_id VARCHAR(256), --id lotu
    arrival_time TIME  --godzina wylotu
)

as
$$
begin
    return query
    select A.city, F.id, F.arrival_time
    FROM flights as F JOIN connections as CO ON F.connection = CO.id
        JOIN Docks as D ON Co.arrival_dock = D.id
        JOIN Airports AS A ON D.airport = A.id
    WHERE F.arrival_date = date_of_arrival and A.city = 'Cracow';
end;
$$
LANGUAGE 'plpgsql'

SELECT * FROM arrival('1979-08-20');

DROP FUNCTION IF EXISTS browser;

create or replace function browser(city_of_arrival VARCHAR(256), date_of_departure DATE, date_of_arrival DATE)
returns TABLE(time_of_departure TIME, duration_of_flight FLOAT,
             departure_airport VARCHAR(256), arrival_airport VARCHAR(256))
as
$$
begin
    return query
    select F.departure_time as time_of_departure, extract(epoch from (F.arrival_time::interval - F.departure_time::time)) / 60 as duration_af_flight, DepartureD.airport, ArrivalD.airport
    from Flights as F join Connections as Co ON F.connection = Co.id
        join Docks as DepartureD on DepartureD.id = Co.departure_dock
        join Airports as DepartureA on DepartureA.id = DepartureD.airport
        join Docks as ArrivalD on ArrivalD.id = Co.arrival_dock
        join Airports as ArrivalA on ArrivalA.id = ArrivalD.airport
    where  DepartureA.city = 'Cracow' and ArrivalA.city = city_of_arrival and F.departure_date = date_of_departure AND F.arrival_date = date_of_arrival;
end;
$$
LANGUAGE 'plpgsql'

SELECT * FROM browser('Cracow', '1977-06-23', '1977-06-24');

create or replace function luggage_cost(ticket_ref varchar(256))
returns int
as
$$
declare total int;
begin
return (select
(
    select coalesce(count(*), 0)
    from luggage as L
    where L.ticket = ticket_ref
) * 80
+
(
    select coalesce(sum(L.width) - 119*count(*), 0)
    from luggage as L
    where L.ticket = ticket_ref
    and L.width > 119
)
+
(
    select coalesce(sum(L.height) - 119*count(*), 0)
    from luggage as L
    where L.ticket = ticket_ref
    and L.height > 119
)
+
(
    select coalesce(sum(L.depth) - 81*count(*), 0)
    from luggage as L
    where L.ticket = ticket_ref
    and L.depth > 81
));
end;
$$
language 'plpgsql';

SELECT * FROM luggage_cost(CAST('9168ce09e9' AS VARCHAR(256)));

create or replace function upcomming_flights(employee_id varchar(256))
returns table(
    id VARCHAR(256),
    connection_id VARCHAR(256),
    departure_time TIME,
    arrival_time TIME,
    plane_serial VARCHAR(256),
    carrier VARCHAR(256),
    departure_date DATE,
    arrival_date DATE
)
as
$$
begin
    return query
    select F.id, F.connection as connection_id, F.departure_time, F.arrival_time, F.plane as plane_serial, C.carrier, F.departure_date, F.arrival_date
    from flights as F join employees_flights as EF on F.id = EF.flight
    join Connections as C on C.id = F.connection
    where EF.employee = employee_id and (F.departure_date > current_date or (F.departure_date = current_date and F.departure_time >= current_time))
    order by F.departure_date, F.departure_time;
end;
$$
language 'plpgsql';

SELECT * FROM upcomming_flights('b81f88f4-54c5-419c-91dd-47af7cda96ad');

create or replace function affordable_flights(price MONEY)
returns table(
    id VARCHAR(256),
    departure_city VARCHAR(256),
    arrival_city VARCHAR(256),
    departure_time TIME,
    arrival_time TIME,
    carrier_name VARCHAR(256),
    departure_date DATE,
    arrival_date DATE
)
as
$$
begin
    return query
    select F.id, DA.city as departure_city, AA.city as arrival_city, F.departure_time, F.arrival_time, Ca.name,  F.departure_date, F.arrival_date
    from Flights as F
    join Connections as C on C.id = F.connection
    join Carriers as Ca on Ca.id = C.carrier
    join Docks as DD on C.departure_dock = DD.id
    join Airports as DA on DD.airport = DA.id
    join Docks as AD on C.arrival_dock = AD.id
    join Airports as AA on AD.airport = AA.id
    where F.departure_date > current_date and F.ticket_cost < price
    order by F.departure_date, F.departure_time;
end;
$$
language 'plpgsql';

SELECT * FROM affordable_flights(CAST(5000.0 AS MONEY)) LIMIT 10;

CREATE OR REPLACE FUNCTION
generate_uuid()
RETURNS VARCHAR(36)
AS $$
BEGIN
   RETURN (SELECT uuid_in(overlay(overlay(md5(random()::text || ':' || clock_timestamp()::text) placing '4' from 13) placing to_hex(floor(random()*(11-8+1) + 8)::int)::text from 17)::cstring));
END;
$$
LANGUAGE 'plpgsql'

SELECT * FROM generate_uuid();

DROP FUNCTION IF EXISTS degrees_to_radians;

CREATE FUNCTION degrees_to_radians(degrees FLOAT)
RETURNS FLOAT
AS $$
    BEGIN
        RETURN degrees * PI() / 180;
    END;
$$
LANGUAGE PLPGSQL;

SELECT * FROM degrees_to_radians(CAST(114 AS FLOAT));

DROP FUNCTION IF EXISTS money_lost_to_discounts;

CREATE FUNCTION
money_lost_to_discounts(connection_id VARCHAR(256))
RETURNS TABLE(
flight_id VARCHAR(256),
plane_capacity INT,
tickets_sold BIGINT,
unused_capacity BIGINT,
ticket_cost MONEY,
expected_ticket_earnings MONEY,
actual_ticket_earnings MONEY,
loss_due_to_discounts MONEY
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        Flights.id AS flight_id,
        -- ArrivalAirports.city AS arrival_city,
        -- DepartureAirports.city AS departure_city,
        PlaneModels.capacity AS plane_capacity,
        COUNT(Tickets.ref) AS tickets_sold,
        PlaneModels.capacity - COUNT(Tickets.ref) AS unused_capacity,
        Flights.ticket_cost AS ticket_cost,
        COUNT(Tickets.ref) * Flights.ticket_cost AS expected_ticket_earnings,
        SUM(Tickets.Cost) AS actual_ticket_earnings,
        COUNT(Tickets.ref) * Flights.ticket_cost - SUM(Tickets.Cost) AS loss_due_to_discounts
    FROM
        Flights
        LEFT JOIN Connections ON Flights.connection = Connections.id
        LEFT JOIN Docks ArrivalDocks ON Connections.arrival_dock = ArrivalDocks.id
        LEFT JOIN Docks DepartureDocks ON Connections.departure_dock = DepartureDocks.id
        LEFT JOIN Airports ArrivalAirports ON ArrivalDocks.airport = ArrivalAirports.id
        LEFT JOIN Airports DepartureAirports ON DepartureDocks.airport = DepartureAirports.id
        LEFT JOIN Tickets ON Flights.id = Tickets.flight
        LEFT JOIN Planes ON Flights.plane = Planes.serial
        LEFT JOIN PlaneModels ON Planes.model = PlaneModels.id
    WHERE Flights.connection = connection_id
    GROUP BY flight_id, plane_capacity
    ORDER BY Flights.arrival_date DESC;
END;
$$
LANGUAGE PLPGSQL

SELECT
    connection,
    COUNT(Tickets.ref) AS ticket_count
FROM
    Tickets
    LEFT JOIN Flights ON Tickets.flight = Flights.id
    LEFT JOIN Connections ON Flights.connection = Connections.id
GROUP BY Flights.connection
ORDER BY ticket_count DESC
LIMIT 10;

SELECT * FROM money_lost_to_discounts('32d3e60a-0f54-4e44-8f1c-dde9ca5a829c') LIMIT 10;
