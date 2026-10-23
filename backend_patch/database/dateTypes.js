'use strict';
// DATE is a calendar date, not an instant. Preserve its SQL YYYY-MM-DD text
// instead of serializing a local-midnight Date through UTC into another day.
require('pg').types.setTypeParser(1082,value=>value);
