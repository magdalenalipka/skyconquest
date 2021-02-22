CREATE TABLE PlaneModels (
  id VARCHAR(256) UNIQUE,
  model VARCHAR(256),
  capacity INT,
  PRIMARY KEY (id)
);

SELECT * FROM plane_models LIMIT 10;

CREATE TABLE Carriers (
  id VARCHAR(256) UNIQUE,
  name VARCHAR(256),
  PRIMARY KEY (id)
);

SELECT * FROM Carriers LIMIT 10;

CREATE TABLE Planes (
  serial VARCHAR(256),
  model VARCHAR(256),
  owner VARCHAR(256),
  PRIMARY KEY (serial),
  FOREIGN KEY (model) REFERENCES PlaneModels (id),
  FOREIGN KEY (owner) REFERENCES Carriers (id)
);

SELECT * FROM Planes LIMIT 10;

CREATE TABLE Airports (
  id VARCHAR(256),
  name VARCHAR(256),
  country VARCHAR(256),
  city VARCHAR(256),
  longitude FLOAT,
  latitude FLOAT,
  PRIMARY KEY (id)
);

SELECT * FROM Airports LIMIT 10;

CREATE TABLE Docks (
  id VARCHAR(256) UNIQUE,
  name VARCHAR(256),
  airport VARCHAR(256),
  PRIMARY KEY (id),
  FOREIGN KEY (airport) REFERENCES airports (id)
);

SELECT * FROM Docks LIMIT 10;

CREATE TABLE Connections (
  id VARCHAR(256),
  departure_time TIME,
  departure_day_of_week INT CHECK (departure_day_of_week BETWEEN 1 and 7),
  departure_dock VARCHAR(256),
  arrival_time TIME,
  arrival_day_of_week INT CHECK (departure_day_of_week BETWEEN 1 and 7),
  arrival_dock VARCHAR(256),
  carrier VARCHAR(256),
  loyality_miles INT DEFAULT 10, -- czemu 10? nikt nie wie
  PRIMARY KEY (id),
  FOREIGN KEY (departure_dock) REFERENCES docks (id),
  FOREIGN KEY (arrival_dock) REFERENCES docks (id),
  FOREIGN KEY (carrier) REFERENCES carriers (id)
);

SELECT * FROM Connections LIMIT 10;

CREATE TABLE Flights (
  id VARCHAR(256),
  connection VARCHAR(256),
  departure_time TIME,
  arrival_time TIME,
  departure_date DATE,
  arrival_date DATE,
  plane VARCHAR(256),
  ticket_cost MONEY,
  PRIMARY KEY (id),
  FOREIGN KEY (plane) REFERENCES Planes (serial),
  FOREIGN KEY (connection) REFERENCES Connections (id)
);

SELECT * FROM Flights LIMIT 10;

CREATE TABLE Passengers (
  id VARCHAR(256) UNIQUE,
  id_type VARCHAR(256),
  name VARCHAR(256),
  surname VARCHAR(256),
  birth_date DATE,
  PRIMARY KEY (id)
);

SELECT * FROM Passengers LIMIT 10;

CREATE TABLE Reservations (
  id VARCHAR(256),
  flight VARCHAR(256),
  passenger VARCHAR(256),
  expire_date DATE,
  expire_time TIME,
  PRIMARY KEY (flight, passenger),
  FOREIGN KEY (flight) REFERENCES Flights (id),
  FOREIGN KEY (passenger) REFERENCES Passengers (id)
);

SELECT * FROM Reservations LIMIT 10;

CREATE TABLE Tickets (
  ref VARCHAR(256),
  passenger VARCHAR(256),
  flight VARCHAR(256),
  cost MONEY,
  PRIMARY KEY (ref),
  FOREIGN KEY (passenger) REFERENCES Passengers (id),
  FOREIGN KEY (flight) REFERENCES Flights (id)
);

SELECT * FROM Tickets LIMIT 10;

CREATE TABLE LoyalityRanks (
  minimum_miles INT,
  rank_name VARCHAR(256),
  discount FLOAT,
  carrier VARCHAR(256),
  PRIMARY KEY (carrier, minimum_miles),
  FOREIGN KEY (carrier) REFERENCES Carriers (id)
);

SELECT * FROM LoyalityRanks ORDER BY minimum_miles ASC LIMIT 10;

CREATE TABLE Miles (
  id VARCHAR(256),
  carrier VARCHAR(256),
  passenger VARCHAR(256),
  miles INT,
  description VARCHAR(256),
  PRIMARY KEY (id),
  FOREIGN KEY (carrier) REFERENCES Carriers (id),
  FOREIGN KEY (passenger) REFERENCES Passengers (id)
);

SELECT * FROM Miles LIMIT 10;

CREATE TABLE Luggage (
  id VARCHAR(256),
  height INT, -- największy wymiar w centymetrach
  width INT, -- średni wymiar w centymetrach
  depth INT, -- najmniejszy wymiar w centymetrach
  ticket VARCHAR(256),
  PRIMARY KEY (id),
  FOREIGN KEY (ticket) REFERENCES Tickets (ref)
);

SELECT * FROM Luggage LIMIT 10;

CREATE TABLE Employees (
  id VARCHAR(256),
  name VARCHAR(256),
  surname VARCHAR(256),
  birth_date DATE,
  job_title VARCHAR(256),
  principal VARCHAR(256),
  PRIMARY KEY (id),
  FOREIGN KEY (principal) REFERENCES Employees (id)
);

SELECT * FROM Employees LIMIT 10;

CREATE TABLE Vacations (
  employee VARCHAR(256),
  start_date DATE,
  end_date DATE,
  PRIMARY KEY (employee, start_date),
  FOREIGN KEY (employee) REFERENCES employees (id)
);

SELECT * FROM Vacations LIMIT 10;

CREATE TABLE Trainings (
  id VARCHAR(256),
  topic VARCHAR(256),
  date DATE,
  PRIMARY KEY (id)
);

SELECT * FROM Trainings LIMIT 10;

CREATE TABLE Employees_Trainings (
  employee VARCHAR(256),
  training VARCHAR(256),
  FOREIGN KEY (employee) REFERENCES Employees (id),
  FOREIGN KEY (training) REFERENCES Trainings (id)
);

SELECT * FROM Employees_Trainings LIMIT 10;

CREATE TABLE Shifts (
  employee VARCHAR(256),
  start_time TIME,
  end_time TIME,
  FOREIGN KEY (employee) REFERENCES Employees (id)
);

SELECT * FROM Shifts LIMIT 10;

CREATE TABLE ShiftsHistory (
  employee VARCHAR(256),
  start_date DATE,
  end_date DATE,
  start_time TIME,
  end_time TIME,
  FOREIGN KEY (employee) REFERENCES Employees (id)
);

SELECT * FROM ShiftsHistory LIMIT 10;

CREATE TABLE Employees_Flights (
  employee VARCHAR(256),
  flight VARCHAR(256),
  FOREIGN KEY (employee) REFERENCES Employees (id),
  FOREIGN KEY (flight) REFERENCES Flights (id)
);

SELECT * FROM Employees_Flights LIMIT 10;

CREATE TABLE Shops (
  id VARCHAR(256),
  name VARCHAR(256),
  location INT,
  PRIMARY KEY (id)
);

SELECT * FROM Shops LIMIT 10;

CREATE TABLE Receipts (
  id VARCHAR(256),
  shop VARCHAR(256),
  date DATE,
  time TIME,
  PRIMARY KEY (id),
  FOREIGN KEY (shop) REFERENCES Shops (id)
);

SELECT * FROM Receipts LIMIT 10;

CREATE TABLE Items (
  id VARCHAR(256),
  name VARCHAR(256),
  price INT CHECK (price > 0),
  shop VARCHAR(256),
  PRIMARY KEY (id),
  FOREIGN KEY (shop) REFERENCES Shops (id)
);

SELECT * FROM Items LIMIT 10;

CREATE TABLE Items_Receipts (
  item VARCHAR(256),
  receipt VARCHAR(256),
  quantity INT CHECK (quantity > 0),
  PRIMARY KEY (item, receipt),
  FOREIGN KEY (item) REFERENCES Items (id),
  FOREIGN KEY (receipt) REFERENCES Receipts (id)
);

SELECT * FROM Items_Receipts LIMIT 10;

CREATE TABLE Suppliers (
  id VARCHAR(256),
  name VARCHAR(256),
  PRIMARY KEY (id)
);

SELECT * FROM Suppliers LIMIT 10;

CREATE TABLE Supplies (
  id VARCHAR(256), -- numer pozwolenia
  supplier VARCHAR(256),
  date DATE,
  PRIMARY KEY (id),
  FOREIGN KEY (supplier) REFERENCES Suppliers (id)
);

SELECT * FROM Supplies LIMIT 10;
