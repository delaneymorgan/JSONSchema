m_js = require("jsonschema")

local js = m_js.new( "./")

local TEST_DIRECTORY = "./testfiles"
local SCHEMA = TEST_DIRECTORY .. "/" .. "schema.json"
local GOOD_JSON = TEST_DIRECTORY .. "/".. "good.json"
local BAD_AGE_1_JSON = TEST_DIRECTORY .. "/".. "bad_age_1.json"
local BAD_AGE_2_JSON = TEST_DIRECTORY .. "/".. "bad_age_2.json"
local BAD_HONORIFIC_JSON = TEST_DIRECTORY .. "/".. "bad_honorific.json"
local BAD_LASTNAME_JSON = TEST_DIRECTORY .. "/".. "bad_lastname.json"
local BAD_HETEROGENEOUS_JSON = TEST_DIRECTORY .. "/".. "bad_heterogeneous.json"

local status, reason = js.validate( SCHEMA, fakeObject)
assert(status)

local fakeObject = js.fakeObject( SCHEMA)
assert(fakeObject)

local goodJSON = js.load( GOOD_JSON)
status, reason = js.validate( SCHEMA, goodJSON)
assert(status)

badJSON = js.load( BAD_HETEROGENEOUS_JSON)
status, reason = js.validate( SCHEMA, badJSON)
print("Expected " .. reason.error)
assert(not status)

local badJSON = js.load( BAD_AGE_1_JSON)
status, reason = js.validate( SCHEMA, badJSON)
print("Expected " .. reason.error)
assert(not status)

badJSON = js.load( BAD_AGE_2_JSON)
status, reason = js.validate( SCHEMA, badJSON)
print("Expected " .. reason.error)
assert(not status)

badJSON = js.load( BAD_HONORIFIC_JSON)
status, reason = js.validate( SCHEMA, badJSON)
print("Expected " .. reason.error)
assert(not status)

badJSON = js.load( BAD_LASTNAME_JSON)
status, reason = js.validate( SCHEMA, badJSON)
print("Expected " .. reason.error)
assert(not status)

print("passed tests")