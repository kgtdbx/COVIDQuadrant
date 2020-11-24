/*--------- Utah FIPS Mapping Allocation by Population ---------------------------------------------------------
County Name     JHU UID Code
Bear River	    84070015
Central Utah	84070016
Southeast Utah	84070017
Southwest Utah	84070018
TriCounty	    84070019
Weber-Morgan	84070020

--https://github.com/CSSEGISandData/COVID-19/issues/3066
Southeast Utah, Utah:
Carbon County, Emery County, and Grand County.
49007, 49015, 49019

Weber-Morgan, Utah:
Weber County and Morgan County.
49057, 49029

Central Utah, Utah:
Juab County, Millard County, Piute County, Sanpete County, Sevier County, and Wayne County.
49023, 49027, 49031, 49039, 49041, 49055

TriCounty, Utah:
Uintah County, Duchesne County, and Daggett County.
49047, 49013, 49009

Bear River, Utah:
Box Elder County.
49003, (?)49005, (?)49033 

Southwest Utah, Utah:
Washington County, Iron County, Kane County, Beaver County, and Garfield County
49053, 49021, 49025, 49001, 49017
--------------------------------------------------------------------------------------------------------------*/
--CREATE TABLE & INSERT VALUES ABOVE
CREATE OR REPLACE TABLE STARSCHEMA_COVID19_QA.PUBLIC.TBL_UTAH_FIPS (
    AREA_NAME varchar(50),
    STATE varchar(50),
    FIPS integer,
    COUNTY_NAME varchar(50),
    POPULATION integer
);


--INSERT MAPPING VALUES
--https://www.utah-demographics.com/counties_by_population
INSERT INTO STARSCHEMA_COVID19_QA.PUBLIC.TBL_UTAH_FIPS VALUES
('Southwest Utah','Utah',49001,'Beaver',6710),
('Bear River','Utah',49003,'Box Elder',56046),
('Bear River','Utah',49005,'Cache',128289),
('Southeast Utah','Utah',49007,'Carbon',20463),
('TriCounty','Utah',49009,'Daggett',950),
('TriCounty','Utah',49013,'Duchesne',19938),
('Southeast Utah','Utah',49015,'Emery',10012),
('Southwest Utah','Utah',49017,'Garfield',5051),
('Southeast Utah','Utah',49019,'Grand',9754),
('Southwest Utah','Utah',49021,'Iron',54839),
('Central Utah','Utah',49023,'Juab',12017),
('Southwest Utah','Utah',49025,'Kane',7886),
('Central Utah','Utah',49027,'Millard',13188),
('Weber-Morgan','Utah',49029,'Morgan',12124),
('Central Utah','Utah',49031,'Piute',1479),
('Bear River','Utah',49033,'Rich',2483),
('Central Utah','Utah',49039,'Sanpete',30939),
('Central Utah','Utah',49041,'Sevier',21620),
('TriCounty','Utah',49047,'Uintah',35734),
('Southwest Utah','Utah',49053,'Washington',177556),
('Central Utah','Utah',49055,'Wayne',2711),
('Weber-Morgan','Utah',49057,'Weber',260213);


--MAKE JOIN AND ALLOCATION SQL IF NULL FOR UTAH
WITH
counties AS (
  SELECT JHU.FIPS, JHU.PROVINCE_STATE, JHU.COUNTY, JHU.DATE, GEOSQL.COUNTY_POPULATION, 
    SUM(JHU.CASES) AS COUNTY_CASES,
    DIV0(COUNTY_CASES,GEOSQL.COUNTY_POPULATION) AS CASES_PER_CAPITA_COUNTY,
    CASES_PER_CAPITA_COUNTY * 100000 AS CASES_PER_100K
  FROM STARSCHEMA_COVID19.PUBLIC.JHU_COVID_19 JHU
  LEFT JOIN (
    SELECT LEFT(CBG,5) AS FIPS, SUM(GEO.TOTAL_POPULATION) AS COUNTY_POPULATION
    FROM SAFEGRAPH_SAFEGRAPH_SHARE.PUBLIC.US_POPULATION_BY_SEX_GEO GEO GROUP BY FIPS) GEOSQL
    ON GEOSQL.FIPS = JHU.FIPS
  WHERE JHU.COUNTRY_REGION = 'United States' AND JHU.DATE = TO_DATE('2020-11-21') AND JHU.CASE_TYPE IN('Confirmed')
  AND JHU.FIPS IS NOT NULL
  GROUP BY JHU.PROVINCE_STATE, JHU.COUNTY, JHU.FIPS, GEOSQL.COUNTY_POPULATION, JHU.DATE, JHU.CASE_TYPE
  ORDER BY JHU.FIPS),
utahCounties AS (
  SELECT FIPS, PROVINCE_STATE, COUNTY_NAME, DATE, COUNTY_POPULATION, COUNTY_CASES_ALLOCATED_BY_POPULATION,
  CASES_PER_CAPITA_COUNTY, CASES_PER_100K FROM
  (SELECT UTAHSQL.FIPS, JHU.PROVINCE_STATE, JHU.COUNTY, UTAHSQL.COUNTY_NAME, JHU.DATE, UTAHSQL.POPULATION AS COUNTY_POPULATION,
    (SUM(UTAHSQL.POPULATION) OVER (PARTITION BY UTAHSQL.AREA_NAME))::INTEGER AS AREA_POPULATION,
    (SUM(JHU.CASES) * (SUM(UTAHSQL.POPULATION) / AREA_POPULATION))::INTEGER AS COUNTY_CASES_ALLOCATED_BY_POPULATION,
    DIV0(COUNTY_CASES_ALLOCATED_BY_POPULATION,UTAHSQL.POPULATION) AS CASES_PER_CAPITA_COUNTY,
    CASES_PER_CAPITA_COUNTY * 100000 AS CASES_PER_100K
  FROM STARSCHEMA_COVID19.PUBLIC.JHU_COVID_19 JHU
  LEFT JOIN (
    SELECT AREA_NAME, STATE, FIPS, COUNTY_NAME, POPULATION
    FROM STARSCHEMA_COVID19_QA.PUBLIC.TBL_UTAH_FIPS) UTAHSQL
  ON JHU.PROVINCE_STATE = UTAHSQL.STATE AND JHU.COUNTY = UTAHSQL.AREA_NAME
  WHERE JHU.COUNTRY_REGION = 'United States' AND JHU.DATE = TO_DATE('2020-11-21') AND JHU.CASE_TYPE IN('Confirmed')
  AND JHU.PROVINCE_STATE = 'Utah' AND JHU.FIPS IS NULL
  GROUP BY JHU.PROVINCE_STATE, JHU.COUNTY, UTAHSQL.COUNTY_NAME, UTAHSQL.FIPS, UTAHSQL.POPULATION, JHU.DATE, JHU.CASE_TYPE, UTAHSQL.AREA_NAME
  ORDER BY UTAHSQL.FIPS))
SELECT * FROM counties
UNION
SELECT * FROM utahCounties;

                       
--County Data with Populations, Deaths and Cases and Utah County Areas Allocated by Population
WITH cases AS 
(
   WITH counties AS 
   (
      SELECT
         JHU.FIPS,
         JHU.PROVINCE_STATE,
         JHU.COUNTY,
         JHU.DATE,
         GEOSQL.COUNTY_POPULATION,
         SUM(JHU.CASES) AS COUNTY_CASES,
         DIV0(COUNTY_CASES, GEOSQL.COUNTY_POPULATION) AS CASES_PER_CAPITA_COUNTY,
         CASES_PER_CAPITA_COUNTY * 100000 AS CASES_PER_100K 
      FROM
         STARSCHEMA_COVID19.PUBLIC.JHU_COVID_19 JHU 
         LEFT JOIN
            (
               SELECT
                  LEFT(CBG, 5) AS FIPS,
                  SUM(GEO.TOTAL_POPULATION) AS COUNTY_POPULATION 
               FROM
                  SAFEGRAPH_SAFEGRAPH_SHARE.PUBLIC.US_POPULATION_BY_SEX_GEO GEO 
               GROUP BY
                  FIPS
            )
            GEOSQL 
            ON GEOSQL.FIPS = JHU.FIPS 
      WHERE
         JHU.COUNTRY_REGION = 'United States' 
         AND JHU.DATE = TO_DATE('2020-11-22') 
         AND JHU.CASE_TYPE IN
         (
            'Confirmed'
         )
         AND JHU.FIPS IS NOT NULL 
      GROUP BY
         JHU.PROVINCE_STATE,
         JHU.COUNTY,
         JHU.FIPS,
         GEOSQL.COUNTY_POPULATION,
         JHU.DATE,
         JHU.CASE_TYPE 
      ORDER BY
         JHU.FIPS
   )
,
   utahCounties AS 
   (
      SELECT
         FIPS,
         PROVINCE_STATE,
         COUNTY_NAME,
         DATE,
         COUNTY_POPULATION,
         COUNTY_CASES_ALLOCATED_BY_POPULATION,
         CASES_PER_CAPITA_COUNTY,
         CASES_PER_100K 
      FROM
         (
            SELECT
               UTAHSQL.FIPS,
               JHU.PROVINCE_STATE,
               JHU.COUNTY,
               UTAHSQL.COUNTY_NAME,
               JHU.DATE,
               UTAHSQL.POPULATION AS COUNTY_POPULATION,
               (
                  SUM(UTAHSQL.POPULATION) OVER (PARTITION BY UTAHSQL.AREA_NAME)
               )
               ::INTEGER AS AREA_POPULATION,
               (
                  SUM(JHU.CASES) * (SUM(UTAHSQL.POPULATION) / AREA_POPULATION)
               )
               ::INTEGER AS COUNTY_CASES_ALLOCATED_BY_POPULATION,
               DIV0(COUNTY_CASES_ALLOCATED_BY_POPULATION, UTAHSQL.POPULATION) AS CASES_PER_CAPITA_COUNTY,
               CASES_PER_CAPITA_COUNTY * 100000 AS CASES_PER_100K 
            FROM
               STARSCHEMA_COVID19.PUBLIC.JHU_COVID_19 JHU 
               LEFT JOIN
                  (
                     SELECT
                        AREA_NAME,
                        STATE,
                        FIPS,
                        COUNTY_NAME,
                        POPULATION 
                     FROM
                        STARSCHEMA_COVID19_QA.PUBLIC.TBL_UTAH_FIPS
                  )
                  UTAHSQL 
                  ON JHU.PROVINCE_STATE = UTAHSQL.STATE 
                  AND JHU.COUNTY = UTAHSQL.AREA_NAME 
            WHERE
               JHU.COUNTRY_REGION = 'United States' 
               AND JHU.DATE = TO_DATE('2020-11-22') 
               AND JHU.CASE_TYPE IN
               (
                  'Confirmed'
               )
               AND JHU.PROVINCE_STATE = 'Utah' 
               AND JHU.FIPS IS NULL 
            GROUP BY
               JHU.PROVINCE_STATE,
               JHU.COUNTY,
               UTAHSQL.COUNTY_NAME,
               UTAHSQL.FIPS,
               UTAHSQL.POPULATION,
               JHU.DATE,
               JHU.CASE_TYPE,
               UTAHSQL.AREA_NAME 
            ORDER BY
               UTAHSQL.FIPS
         )
   )
   SELECT
      * 
   FROM
      counties 
   UNION
   SELECT
      * 
   FROM
      utahCounties 
)
,
deaths AS
(
   WITH countiesDeaths AS 
   (
      SELECT
         JHU.FIPS,
         JHU.PROVINCE_STATE,
         JHU.COUNTY,
         JHU.DATE,
         GEOSQL.COUNTY_POPULATION,
         SUM(JHU.CASES) AS COUNTY_DEATHS,
         DIV0(COUNTY_DEATHS, GEOSQL.COUNTY_POPULATION) AS DEATHS_PER_CAPITA_COUNTY,
         DEATHS_PER_CAPITA_COUNTY * 100000 AS DEATHS_PER_100K 
      FROM
         STARSCHEMA_COVID19.PUBLIC.JHU_COVID_19 JHU 
         LEFT JOIN
            (
               SELECT
                  LEFT(CBG, 5) AS FIPS,
                  SUM(GEO.TOTAL_POPULATION) AS COUNTY_POPULATION 
               FROM
                  SAFEGRAPH_SAFEGRAPH_SHARE.PUBLIC.US_POPULATION_BY_SEX_GEO GEO 
               GROUP BY
                  FIPS
            )
            GEOSQL 
            ON GEOSQL.FIPS = JHU.FIPS 
      WHERE
         JHU.COUNTRY_REGION = 'United States' 
         AND JHU.DATE = TO_DATE('2020-11-22') 
         AND JHU.CASE_TYPE IN
         (
            'Deaths'
         )
         AND JHU.FIPS IS NOT NULL 
      GROUP BY
         JHU.PROVINCE_STATE,
         JHU.COUNTY,
         JHU.FIPS,
         GEOSQL.COUNTY_POPULATION,
         JHU.DATE,
         JHU.CASE_TYPE 
      ORDER BY
         JHU.FIPS
   )
,
   utahCountiesDeaths AS 
   (
      SELECT
         FIPS,
         PROVINCE_STATE,
         COUNTY_NAME,
         DATE,
         COUNTY_POPULATION,
         COUNTY_DEATHS_ALLOCATED_BY_POPULATION,
         DEATHS_PER_CAPITA_COUNTY,
         DEATHS_PER_100K 
      FROM
         (
            SELECT
               UTAHSQL.FIPS,
               JHU.PROVINCE_STATE,
               JHU.COUNTY,
               UTAHSQL.COUNTY_NAME,
               JHU.DATE,
               UTAHSQL.POPULATION AS COUNTY_POPULATION,
               (
                  SUM(UTAHSQL.POPULATION) OVER (PARTITION BY UTAHSQL.AREA_NAME)
               )
               ::INTEGER AS AREA_POPULATION,
               (
                  SUM(JHU.CASES) * (SUM(UTAHSQL.POPULATION) / AREA_POPULATION)
               )
               ::INTEGER AS COUNTY_DEATHS_ALLOCATED_BY_POPULATION,
               DIV0(COUNTY_DEATHS_ALLOCATED_BY_POPULATION, UTAHSQL.POPULATION) AS DEATHS_PER_CAPITA_COUNTY,
               DEATHS_PER_CAPITA_COUNTY * 100000 AS DEATHS_PER_100K 
            FROM
               STARSCHEMA_COVID19.PUBLIC.JHU_COVID_19 JHU 
               LEFT JOIN
                  (
                     SELECT
                        AREA_NAME,
                        STATE,
                        FIPS,
                        COUNTY_NAME,
                        POPULATION 
                     FROM
                        STARSCHEMA_COVID19_QA.PUBLIC.TBL_UTAH_FIPS
                  )
                  UTAHSQL 
                  ON JHU.PROVINCE_STATE = UTAHSQL.STATE 
                  AND JHU.COUNTY = UTAHSQL.AREA_NAME 
            WHERE
               JHU.COUNTRY_REGION = 'United States' 
               AND JHU.DATE = TO_DATE('2020-11-22') 
               AND JHU.CASE_TYPE IN
               (
                  'Deaths'
               )
               AND JHU.PROVINCE_STATE = 'Utah' 
               AND JHU.FIPS IS NULL 
            GROUP BY
               JHU.PROVINCE_STATE,
               JHU.COUNTY,
               UTAHSQL.COUNTY_NAME,
               UTAHSQL.FIPS,
               UTAHSQL.POPULATION,
               JHU.DATE,
               JHU.CASE_TYPE,
               UTAHSQL.AREA_NAME 
            ORDER BY
               UTAHSQL.FIPS
         )
   )
   SELECT
      * 
   FROM
      countiesDeaths 
   UNION
   SELECT
      * 
   FROM
      utahCountiesDeaths 
)
SELECT
   cases.*,
   deaths.COUNTY_DEATHS,
   deaths.DEATHS_PER_CAPITA_COUNTY,
   deaths.DEATHS_PER_100K 
FROM
   cases 
   LEFT JOIN
      deaths 
      on cases.FIPS = deaths.FIPS 
WHERE
   cases.COUNTY <> 'unassigned' 
   AND cases.FIPS IS NOT NULL 
   AND cases.PROVINCE_STATE IN 
   (
      'Alabama',
      'Alaska',
      'Arizona',
      'Arkansas',
      'California',
      'Colorado',
      'Connecticut',
      'Delaware',
      'District of Columbia',
      'Florida',
      'Georgia',
      'Hawaii',
      'Idaho',
      'Illinois',
      'Indiana',
      'Iowa',
      'Kansas',
      'Kentucky',
      'Louisiana',
      'Maine',
      'Maryland',
      'Massachusetts',
      'Michigan',
      'Minnesota',
      'Mississippi',
      'Missouri',
      'Montana',
      'Nebraska',
      'Nevada',
      'New Hampshire',
      'New Jersey',
      'New Mexico',
      'New York',
      'North Carolina',
      'North Dakota',
      'Ohio',
      'Oklahoma',
      'Oregon',
      'Pennsylvania',
      'Rhode Island',
      'South Carolina',
      'South Dakota',
      'Tennessee',
      'Texas',
      'Utah',
      'Vermont',
      'Virgin Islands',
      'Virginia',
      'Washington',
      'West Virginia',
      'Wisconsin',
      'Wyoming'
   )
;
