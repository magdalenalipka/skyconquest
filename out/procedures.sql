create procedure confirm_reservation(id_r VARCHAR(256))
language 'plpgsql'
as $$
BEGIN
    if not exists (select R.id FROM reservations as R
                    where R.id = id_r)
                    then
	                    RAISE EXCEPTION 'Nie ma rezerwacji na takie id';
                        ROLLBACK;
    END IF;
    if (((select expire_date from Reservations where id=id_r) < CURRENT_DATE) OR
        ((select expire_date from Reservations where id=id_r) = CURRENT_DATE AND (select expire_time from Reservations where id=id_r) > current_time )) then
            RAISE EXCEPTION 'Rezerwacja wygasla na dany lot';
            ROLLBACK;
    END IF;

    declare ticket_number INT
    select random() into ticket_number
    declare discount_for_passenger INT
    discount_for_passenger = select disc.discount from Reservations as R JOIN flights as F ON R.flight = F.id
    JOIN Connections AS Co ON F.connection = Co.id
    JOIN discounts_per_carrier AS disc ON disc.carrier_id = carrier_id AND disc.passenger_id = R.passenger
    declare price MONEY
    price = select ticket_cost from Flights as F JOIN Reservations as R ON F.id = R.flight where R.id = id_r
    insert into Tickets
	values(ticket_number,(select R.passenger from reservations as R
                    where R.id = @id_p),(select R.flight from reservations as R
                    where R.id = @id_p),price * (100-discount_for_passenger)/100);

    select ticket_number
end; $$

create procedure make_reservation(id_f VARCHAR(256), id_p VARCHAR(256))
language 'plpgsql'
as $$
BEGIN
if not exists (select F.id FROM flights as F
                    where F.id = id_f)
                    then
	                    RAISE EXCEPTION 'Nie ma lotu o takim id';
end if;

if not exists (select P.id FROM passengers as P
                    where P.id = id_p)
                    then
	                    RAISE EXCEPTION 'Nie ma pasazera o takim id';
end if;

insert into  reservations
values (CONCAT(id_f + '_' + id_p),id_f, id_p);
end; $$

create procedure delete_reservation(id_r VARCHAR(256))
language 'plpgsql'
as $$
begin
if not exists (select R.id from reservations as R
                where R.id = id_r)
				then
                RAISE EXCEPTION 'nie ma takiej rezerwacji';
END if;
delete from reservations
where id = id_r;
end; $$

drop procedure if exists quarantine_employees;
create or replace procedure quarantine_employees(flight_id varchar(256))
as
$$
declare
    start_city varchar(256);
    end_city varchar(256);
    date_of_incident date;
    time_of_incident time;
begin
    insert
    into vacations
    select EF.employee as employee, current_date as start_date, current_date + integer '14' as end_date
    from employees_flights as EF
    where EF.flight = flight_id;

    select A.city
        from flights as F
        join Connections as C on C.id = F.connection
        join Docks as D on C.departure_dock = D.id
        join Airports as A on D.airport = A.id
        where F.id = flight_id
    into start_city;

    select A.city
        from flights as F
        join Connections as C on C.id = F.connection
        join Docks as D on C.departure_dock = D.id
        join Airports as A on D.airport = A.id
        where F.id = flight_id
    into end_city;

    if (start_city = 'Cracow')
    then
        select departure_time from flight where id = flight_id
        into time_of_incident;
        select departure_date from flight where id = flight_id
        into time_of_incident;
    end if;

    if (end_city = 'Cracow')
    then
        select arrival_time from flight where id = flight_id
        into time_of_incident;
        select arrival_date from flight where id = flight_id
        into time_of_incident;
    end if;

    insert
    into vacations
    select E.id as employee, current_date as start_date, current_date + integer '14' as end_date
    from employees as E join shiftshistory as SH
    on E.id = SH.employee
    where SH.start_date <= date_of_incident and (SH.end_date >= date_of_incident or SH.end_date is null)
        and SH.start_time >= time_of_incident and SH.end_time <= time_of_incident;

end;
$$
language 'plpgsql'

CALL quarantine_employees('a2d40fc0-8998-4899-a426-09b7569c5440');

drop procedure if exists decrease_miles;
create procedure decrease_miles(carrier_id VARCHAR(256), quantity int)
as
$$
begin
update connections
set loyality_miles = loyality_miles * 0.9
where connections.id in (
    select P.id as connection from (
        select C.id, count(*) as popularity
        from Connections as C
        join Flights as F on F.connection = C.id
        join Tickets as T on T.flight = F.id
        where C.carrier = carrier_id
        group by C.id
    ) as P
    order by P.popularity
    limit quantity
);
end;
$$
language 'plpgsql'

select P.* as connection from (
        select C.id, C.loyality_miles, count(*) as popularity
        from Connections as C
        join Flights as F on F.connection = C.id
        join Tickets as T on T.flight = F.id
        where C.carrier = 'aa2307b4-533f-479c-b987-2bcf2a2e5e14'
        group by C.id
    ) as P
order by P.popularity
limit 10;

CALL decrease_miles('aa2307b4-533f-479c-b987-2bcf2a2e5e14', 5)

select P.* as connection from (
        select C.id, C.loyality_miles, count(*) as popularity
        from Connections as C
        join Flights as F on F.connection = C.id
        join Tickets as T on T.flight = F.id
        where C.carrier = 'aa2307b4-533f-479c-b987-2bcf2a2e5e14'
        group by C.id
    ) as P
order by P.popularity
limit 10;

drop procedure if exists add_flights;
create procedure add_flights(connection_id VARCHAR(256), plane_id VARCHAR(256), price MONEY)
as
$$
    declare todays integer;
begin

    if not exists (select * from Planes where serial = plane_id) or not exists (select * from Connections where id = connection_id)
    then
        rollback;
    end if;

    todays := date_part('isodow', current_date);

    create temp table first_dates (
        dow int,
        date DATE
    );

    insert into first_dates values (todays, current_date);
    insert into first_dates values ((todays+1)%7, current_date + integer '1');
    insert into first_dates values ((todays+2)%7, current_date + integer '2');
    insert into first_dates values ((todays+3)%7, current_date + integer '3');
    insert into first_dates values ((todays+4)%7, current_date + integer '4');
    insert into first_dates values ((todays+5)%7, current_date + integer '5');
    insert into first_dates values ((todays+6)%7, current_date + integer '6');

    insert into Flights
    select generate_uuid() as id, C.id as connection, C.departure_time, C.arrival_time, FDD.date as departure_date, FDA.date as arrival_date, plane_id as plane, price as ticket_cost
    from Connections as C
    join first_dates as FDD on C.departure_day_of_week = FDD.dow
    join first_dates as FDA on C.arrival_day_of_week = FDA.dow
    where C.id = connection_id;

    insert into Flights
    select generate_uuid() as id, C.id as connection, C.departure_time, C.arrival_time, FDD.date  + integer '7' as departure_date, FDA.date  + integer '7' as arrival_date, plane_id as plane, price as ticket_cost
    from Connections as C
    join first_dates as FDD on C.departure_day_of_week = FDD.dow
    join first_dates as FDA on C.arrival_day_of_week = FDA.dow
    where C.id = connection_id;

    insert into Flights
    select generate_uuid() as id, C.id as connection, C.departure_time, C.arrival_time, FDD.date  + integer '14' as departure_date, FDA.date  + integer '14' as arrival_date, plane_id as plane, price as ticket_cost
    from Connections as C
    join first_dates as FDD on C.departure_day_of_week = FDD.dow
    join first_dates as FDA on C.arrival_day_of_week = FDA.dow
    where C.id = connection_id;

    insert into Flights
    select generate_uuid() as id, C.id as connection, C.departure_time, C.arrival_time, FDD.date  + integer '21' as departure_date, FDA.date  + integer '21' as arrival_date, plane_id as plane, price as ticket_cost
    from Connections as C
    join first_dates as FDD on C.departure_day_of_week = FDD.dow
    join first_dates as FDA on C.arrival_day_of_week = FDA.dow
    where C.id = connection_id;

end;
$$
language 'plpgsql'

SELECT * FROM FLIGHTS where connection = '887e8b69-0fcf-4b68-b9ff-966903843c0a';

CALL add_flights('887e8b69-0fcf-4b68-b9ff-966903843c0a', '686-86-3326', CAST(100 as MONEY));

SELECT * FROM FLIGHTS where connection = '887e8b69-0fcf-4b68-b9ff-966903843c0a';

DROP PROCEDURE IF EXISTS change_discount;

CREATE OR REPLACE PROCEDURE
change_discount(
    input_passenger VARCHAR(256),
    input_carrier VARCHAR(256),
    input_rank_name VARCHAR(256)
)
LANGUAGE PLPGSQL
AS $$
BEGIN
    INSERT INTO miles VALUES (
        generate_uuid(),
        input_carrier,
        input_passenger,
        (
                SELECT minimum_miles
                FROM LoyalityRanks LR
                WHERE
                LR.carrier = input_carrier
                AND
                LR.rank_name = input_rank_name
        ) - (SELECT carrier_miles FROM discounts_per_carrier WHERE passenger_id = input_passenger AND carrier_id = input_carrier) + 1,
        'artificially changing miles count to change passenger rank'
    );
END;
$$

SELECT * FROM discounts_per_carrier ORDER BY RANDOM() LIMIT 1;

SELECT * FROM LoyalityRanks WHERE carrier = '31d7f99b-b3e4-4ad9-8341-917749339183';

CALL change_discount('fc08dd1d-d1e4-4535-90a3-28cd1c6e5e83', '31d7f99b-b3e4-4ad9-8341-917749339183', 'CornflowerBlue');

SELECT * FROM discounts_per_carrier WHERE passenger_id = 'fc08dd1d-d1e4-4535-90a3-28cd1c6e5e83' AND carrier_id = '31d7f99b-b3e4-4ad9-8341-917749339183';

CREATE OR REPLACE PROCEDURE
replace_plane(flight VARCHAR(256))
AS $$
BEGIN
    UPDATE Flights SET Flights.plane_serial = (
        SELECT Planes.serial
        FROM Planes LEFT JOIN Flights ON Flights.plane = Planes.serial
        WHERE
            (
                departure_date > (SELECT arrival_date FROM Flights WHERE Flights.id = flight)
                AND
                arrival_date < (SELECT departure_date FROM Flights WHERE Flights.id = flight)
            )
            OR Flights.id IS NULL
        AND
            plane NOT IN (
            SELECT plane
            FROM Flights F
            WHERE
                arrival_date > F.departure_date AND F.departure_date > departure_date
            )
    )
    WHERE Flights.id = flight;
END;
$$
LANGUAGE PLPGSQL

CREATE OR REPLACE PROCEDURE
lower_prices_for_least_popular_items()
AS $$
   BEGIN

   UPDATE Items SET price = 0.9 * price
   WHERE Items.id IN (
         SELECT item FROM (
                SELECT item, SUM(quantity) AS times_occured, price
                FROM Items_Receipts LEFT JOIN Items ON Items_Receipts.Item = Items.id
                GROUP BY item, price
                ORDER BY times_occured, item ASC
                LIMIT 10
         ) AS LeastBought
   );

   END;
$$
LANGUAGE PLPGSQL

SELECT item, SUM(quantity) AS times_occured, price
FROM Items_Receipts LEFT JOIN Items ON Items_Receipts.Item = Items.id
GROUP BY item, price
ORDER BY times_occured, item ASC
LIMIT 10;

CALL lower_prices_for_least_popular_items();

SELECT item, SUM(quantity) AS times_occured, price
FROM Items_Receipts LEFT JOIN Items ON Items_Receipts.Item = Items.id
GROUP BY item, price
ORDER BY times_occured, item ASC
LIMIT 10;
