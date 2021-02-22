create or replace view list_of_arrival_for_today
AS
SELECT F.id as id_flight, Co.departure_dock, Co.arrival_dock, F.departure_time, F.arrival_time
from flights as F JOIN connections as Co on F.connection = Co.id
    JOIN Docks AS D ON D.id = Co.arrival_dock
    JOIN Airports as A ON A.id = D.id
where F.connection = Co.id and F.arrival_date = current_date and A.city= 'Cracow'

SELECT * FROM list_of_arrival_for_today;

create or replace view list_of_departure_for_today
AS
SELECT F.id as id_flight, Co.departure_dock, Co.arrival_dock, F.departure_time, F.arrival_time
from flights as F JOIN connections as Co on F.connection = Co.id
    JOIN Docks AS D ON D.id = Co.departure_dock
    JOIN Airports as A ON A.id = D.id
where F.connection = Co.id and F.departure_date = current_date and A.city = 'Cracow'

SELECT * FROM list_of_departure_for_today;

create view quick_travel
AS
    SELECT Co.departure_dock as departure, Co.departure_day_of_week, F.departure_date
    FROM Flights as F join connections as Co on F.connection = Co.id
	join docks as D ON Co.departure_dock = D.id
    JOIN Airports as A ON A.id = D.id
    where (Co.arrival_time::interval - Co.departure_time::time)/60 < '02:00' AND A.name = 'Cracow_airport';

SELECT * FROM quick_travel;

create or replace view employees_needing_training
as
select E.id, E.name, E.surname
from employees as E
where E.id not in (
    select distinct ET.employee
    from trainings as T join employees_trainings as ET on T.id = ET.employee
    where T.date > current_date - 365
);

SELECT * FROM employees_needing_training LIMIT 10;

create or replace view upcomming_dock_flights
as
select R.*
from (
    select O.*, rank() over(partition by O.departure_dock order by O.departure_date, O.departure_time) as rank
    from (
        select F.* , C.departure_dock, A.city
        from flights as F
        join connections as C on F.connection = C.id
        join Docks as D on C.departure_dock = D.id
        join airports as A on D.airport = A.id
        where A.city = 'Cracow' and F.departure_date >= current_date and F. departure_time >= current_time
    ) as O
) as R
where R.rank = 1

SELECT * FROM upcomming_dock_flights;

create view carriers_earnings
as
    select Ca.id, sum(T.cost) as earnings
    from Carriers as Ca
    join Connections as Co on Ca.id = Co.carrier
    join Flights as F on  F.connection = Co.id
    join Tickets as T on T.flight = F.id
    group by Ca.id

SELECT * FROM carriers_earnings;

SELECT
    Passengers.id AS passenger,
    Passengers.name AS name,
    Passengers.surname AS surname,
    Carriers.id AS carrier,
    Carriers.name AS carrier_name,
    SUM(miles) AS carrier_miles
FROM
    Passengers
    RIGHT JOIN Miles ON Passengers.id = Miles.passenger
    LEFT JOIN Carriers ON Miles.carrier = Carriers.id
GROUP BY Passengers.id, Carriers.id
ORDER BY Passengers.id
LIMIT 10;

DROP VIEW IF EXISTS discounts_per_carrier;

CREATE VIEW discounts_per_carrier AS
SELECT
    passenger_id,
    name,
    surname,
    carrier_id,
    carrier_name,
    carrier_miles,
    (SELECT
        rank_name
    FROM LoyalityRanks
    WHERE
        carrier = Passengers_Carriers.carrier_id
        AND
        minimum_miles < Passengers_Carriers.carrier_miles
    ORDER BY minimum_miles DESC
    LIMIT 1) AS rank_name,
    (SELECT
        discount
    FROM LoyalityRanks
    WHERE
        carrier = Passengers_Carriers.carrier_id
        AND
        minimum_miles < Passengers_Carriers.carrier_miles
    ORDER BY minimum_miles DESC
    LIMIT 1) AS discount
FROM
    (
        SELECT
            Passengers.id AS passenger_id,
            Passengers.name AS name,
            Passengers.surname AS surname,
            Carriers.id AS carrier_id,
            Carriers.name AS carrier_name,
            SUM(miles) AS carrier_miles
        FROM
            Passengers
            RIGHT JOIN Miles ON Passengers.id = Miles.passenger
            LEFT JOIN Carriers ON Miles.carrier = Carriers.id
        GROUP BY passenger_id, carrier_id
    ) AS Passengers_Carriers;

select * from discounts_per_carrier;

DROP VIEW IF EXISTS planes_details;

CREATE VIEW planes_details AS
SELECT
    PlaneModels.id AS model,
    Carriers.name AS owner,
    PlaneModels.capacity AS capacity
FROM
    Planes
    LEFT JOIN PlaneModels ON Planes.model = PlaneModels.id
    LEFT JOIN Carriers ON Planes.owner = Carriers.id;

SELECT * FROM planes_details;

DROP VIEW IF EXISTS best_passengers;

CREATE VIEW best_passengers AS
SELECT
    passengers.name AS name,
    passengers.surname AS surname,
    SUM(miles) as miles
FROM
    Passengers
    RIGHT JOIN Miles ON Passengers.id = Miles.passenger
GROUP BY passengers.id
ORDER BY miles DESC;

SELECT * FROM best_passengers LIMIT 10;
