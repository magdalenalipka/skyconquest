create or replace function control_capacity_tgr() RETURNS trigger AS $$
    declare QuantityOfPassengers INT;
    capacity_of_plane INT;
    BEGIN

    QuantityOfPassengers := (select count(*) from Tickets where(flight = new.flight));
    capacity_of_plane := (select PM.capacity FROM Flights as F join Planes AS P ON F.plane = P.serial
                            JOIN PlaneModels AS PM ON PM.id = P.model
                            where F.id = NEW.flight);

    if (QuantityOfPassengers = capacity_of_plane) then
         RAISE EXCEPTION 'Za duzo pasazerow -> nie mozna sprzedac biletu';
         ROLLBACK;
    END IF;
    RETURN NEW;
    end; $$
    language 'plpgsql';

drop trigger control_capacity on Reservations;

create trigger control_capacity
BEFORE INSERT OR UPDATE ON Reservations
for each row execute procedure control_capacity_tgr();

SELECT Flights.id AS flight, capacity, COUNT(Tickets.ref) AS passengers_count
FROM Flights
LEFT JOIN Tickets ON Flights.id = Tickets.flight
LEFT JOIN Planes ON Flights.plane = Planes.serial
LEFT JOIN PlaneModels ON Planes.model = PlaneModels.id
GROUP BY Flights.id, capacity
ORDER BY passengers_count DESC LIMIT 10;

create or replace function update_reservations()
returns trigger
as
$$
begin
    update reservations
    set expire_date = current_date + 14, expire_time = current_time
    where id = new.id;
    return new;
end;
$$
language 'plpgsql';

drop trigger monitor_reservations on reservations;

create trigger monitor_reservations
after insert
on "reservations"
for each row execute function update_reservations();

INSERT INTO Reservations VALUES (
       generate_uuid(),
       'a2d40fc0-8998-4899-a426-09b7569c5440',
       '0d23da67-045e-4f14-866f-3d49242290aa'
);

SELECT * FROM Reservations
WHERE passenger='0d23da67-045e-4f14-866f-3d49242290aa' AND flight='a2d40fc0-8998-4899-a426-09b7569c5440';

create or replace function delete_flights_function() returns trigger as $$
begin
    delete from flights
    where connection_id = old.id and departure_date > current_date;
    return new;
end; $$
language 'plpgsql';

create trigger delete_flights
after delete
on connections
for each row
execute function delete_flights_function();

create or replace function update_shifts_history_on_insertion()
returns trigger
as
$$
begin
    -- add shift sets with start_date = today and empty end_date
    insert into shiftshistory(start_date, end_date, start_time, end_time, employee)
    select current_date as start_date, null as end_date, start_time, end_time, employee from inserted;
    return new;
end;
$$
language 'plpgsql';

create or replace function update_shifts_history_on_update()
returns trigger
as
$$
begin
    -- set today's date as end of previous shift sets
    update shiftshistory
    set end_date = current_date - integer '1'
    where employee in (select employee from deleted) and end_date is null;

    -- add shift sets with start_date = today and empty end_date
    insert into shiftshistory(start_date, end_date, start_time, end_time, employee)
    select current_date as start_date, null as end_date, start_time, end_time, employee from inserted;
end;
$$
language 'plpgsql';

drop trigger if exists monitor_shifts_updates on shifts;
drop trigger if exists monitor_shifts_inserts on shifts;

create trigger monitor_shifts_updates
after update
on "shifts"
referencing old table as deleted new table as inserted
for each statement execute function update_shifts_history_on_update();

create trigger monitor_shifts_inserts
after insert
on "shifts"
referencing new table as inserted
for each statement execute function update_shifts_history_on_insertion();

INSERT INTO Shifts VALUES (
       'b0160727-6c0b-47c9-8480-970b91d46994',
       '12:00',
       '20:00'
);

SELECT * FROM ShiftsHistory WHERE employee = 'b0160727-6c0b-47c9-8480-970b91d46994';

create or replace function update_vacations()
returns trigger
as
$$
declare
    conflict_employee varchar(256);
    conflict_start date;
begin
    conflict_employee := (select V.employee from vacations as V
    where V.employee = new.employee and ( ( V.start_date <= new.start_date and V.end_date >= new.start_date ) or ( V.start_date <= new.end_date and V.end_date >= new.end_date ) ) and (V.start_date <> new.start_date or V.end_date <> new.end_date)
    );

    conflict_start := (select V.start_date from vacations as V
    where V.employee = new.employee and ( ( V.start_date <= new.start_date and V.end_date >= new.start_date ) or ( V.start_date <= new.end_date and V.end_date >= new.end_date ) ) and (V.start_date <> new.start_date or V.end_date <> new.end_date)
    );

    if conflict_employee is not null
    then
        update vacations
        set start_date = least(
            (select start_date from vacations where
            employee = conflict_employee and start_date = conflict_start),
            new.start_date
            ),
        end_date = greatest(
            (select end_date from vacations
            where employee = conflict_employee and start_date = conflict_start),
            new.end_date
            )
        where employee = conflict_employee and start_date = conflict_start;
        delete from vacations where employee = new.employee and start_date = new.start_date and end_date = new.end_date;
    end if;

    return new;
end;
$$ language 'plpgsql';

create trigger monitor_vacations
after insert
on "vacations"
for each row
execute procedure update_vacations();

INSERT INTO Vacations VALUES ('b0160727-6c0b-47c9-8480-970b91d46994', '2020-11-01', '2020-11-20');
INSERT INTO Vacations VALUES ('b0160727-6c0b-47c9-8480-970b91d46994', '2020-11-19', '2020-11-24');

select * from vacations where employee = 'b0160727-6c0b-47c9-8480-970b91d46994';

create or replace function update_flights_details()
returns trigger
as
$$
begin
    update flights
    set departure_time = (select departure_time from connections where id = new.connection),
    arrival_time = (select arrival_time from connections where id = new.connection)
    where flights.id = new.id;
    return new;
end;
$$
language 'plpgsql';

create trigger set_flights_details
after insert
on "flights"
-- referencing new table as inserted
for each row
execute procedure update_flights_details();

INSERT INTO Flights(id, connection) VALUES (generate_uuid(), '887e8b69-0fcf-4b68-b9ff-966903843c0a');

SELECT F.* FROM Flights as F
WHERE connection = '887e8b69-0fcf-4b68-b9ff-966903843c0a';

create or replace function update_luggage()
returns trigger
as
$$
begin
    update luggage
    set height = width, width = height
    where id=new.id and width > height;

    update luggage
    set height = depth, depth = height
    where id=new.id and depth > height;

    update luggage
    set width = depth, depth = width
    where id=new.id and depth > width;

    return new;
end;
$$
language 'plpgsql';

drop trigger if exists monitor_luggage on Luggage;
create trigger monitor_luggage
after insert or update
on "luggage"
-- referencing new table as inserted
for each row execute function update_luggage();

INSERT INTO Luggage VALUES (generate_uuid(), 100, 200, 150, '2b8c997fe3');

SELECT * FROM Luggage WHERE ticket='2b8c997fe3';

CREATE OR REPLACE FUNCTION
add_miles_for_a_ticket()
RETURNS TRIGGER
AS $$
   BEGIN
      INSERT INTO miles
      VALUES (
             generate_uuid(),
             (SELECT carrier FROM Flights LEFT JOIN Connections ON Flights.connection = Connections.id WHERE Flights.id = new.flight),
             new.passenger,
             (SELECT loyality_miles FROM Flights LEFT JOIN Connections ON Flights.connection = Connections.id WHERE Flights.id = new.flight),
             'miles for flight with ticket ' || new.ref
      );
      RETURN NEW;
   END;
$$
LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS add_miles_for_a_ticket_trigger ON tickets;

CREATE TRIGGER add_miles_for_a_ticket_trigger
AFTER INSERT ON tickets
FOR EACH ROW EXECUTE PROCEDURE add_miles_for_a_ticket();

INSERT INTO Tickets VALUES (generate_uuid(), '0d23da67-045e-4f14-866f-3d49242290aa', 'a2d40fc0-8998-4899-a426-09b7569c5440', 1200);

SELECT * FROM Miles WHERE passenger='0d23da67-045e-4f14-866f-3d49242290aa';

CREATE OR REPLACE
FUNCTION add_default_miles_for_a_connection() RETURNS TRIGGER AS $$
DECLARE
    earth_radius INTEGER;
    d_lat FLOAT;
    d_lon FLOAT;
    lat1 FLOAT;
    lat2 FLOAT;
    lon1 FLOAT;
    lon2 FLOAT;
    a FLOAT;
    c FLOAT;
    default_miles INTEGER;
BEGIN
    earth_radius := 3963;

    lat2 := (
            SELECT
                latitude
            FROM
                Docks
                LEFT JOIN Airports ON Docks.airport = Airports.id
                WHERE Docks.id = NEW.arrival_dock
            );
    lon2 := (
            SELECT
                longitude
            FROM
                Docks
                LEFT JOIN Airports ON Docks.airport = Airports.id
                WHERE Docks.id = NEW.arrival_dock
            );

    lat1 := (
            SELECT
                latitude
            FROM
                Docks
                LEFT JOIN Airports ON Docks.airport = Airports.id
                WHERE Docks.id = NEW.departure_dock
            );
    lon1 := (
            SELECT
                longitude
            FROM
                Docks
                LEFT JOIN Airports ON Docks.airport = Airports.id
                WHERE Docks.id = NEW.departure_dock
            );

    d_lat := (degrees_to_radians(lat2 - lat1));
    d_lon := (degrees_to_radians(lon2 - lon1));

    lat1 := (degrees_to_radians(lat1));
    lat2 := (degrees_to_radians(lat2));

    a := SIN(d_lat / 2) * SIN(d_lat / 2) + SIN(d_lon / 2) * SIN(d_lon / 2) * COS(lat1) * COS(lat2);
    c := 2 * ATAN2(SQRT(a), SQRT(1-a));
    default_miles := earth_radius * c;

    UPDATE Connections SET loyality_miles = default_miles WHERE id=NEW.id;

    RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS add_default_miles_for_a_connection_trigger ON connections;

CREATE TRIGGER add_default_miles_for_a_connection_trigger
AFTER INSERT ON connections
FOR EACH ROW
EXECUTE PROCEDURE add_default_miles_for_a_connection();

INSERT INTO Airports VALUES (
       generate_uuid(),
       'Testowe Lotnisko 1',
       'Polska',
       'Wałbrzych',
       50.46,
       16.17
);

INSERT INTO Airports VALUES (
       generate_uuid(),
       'Testowe Lotnisko 2',
       'USA',
       'Tulsa',
       36.15,
       -95.99
);

INSERT INTO Docks VALUES (
       '1111-2222-3333',
       'A1',
       (SELECT id FROM Airports WHERE name='Testowe Lotnisko 1')
);

INSERT INTO Docks VALUES (
       '3333-2222-1111',
       'A1',
       (SELECT id FROM Airports WHERE name='Testowe Lotnisko 2')
);

INSERT INTO Connections VALUES (
       '1111-1111-1111',
       '19:30',
       4,
       '1111-2222-3333',
       '05:30',
       5,
       '3333-2222-1111',
       (SELECT id FROM Carriers ORDER BY RANDOM() LIMIT 1)
);

SELECT * FROM Connections WHERE id='1111-1111-1111';

CREATE OR REPLACE FUNCTION update_flights_details()
RETURNS TRIGGER
AS
$$
BEGIN
    UPDATE FLIGHTS
    SET
        departure_time = (SELECT departure_time FROM Connections WHERE id = NEW.id),
        arrival_time = (SELECT arrival_time FROM Connections WHERE id = NEW.id)
    WHERE flights.id = NEW.id;
    RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS set_flights_details ON flights;

CREATE TRIGGER set_flights_details
AFTER INSERT
ON flights
FOR EACH ROW
EXECUTE PROCEDURE update_flights_details();
