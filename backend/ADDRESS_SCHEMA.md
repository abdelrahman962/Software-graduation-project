# Address Schema Standardization

## Overview
All models now use a standardized address schema for consistency across the system. This makes location-based queries and data management much easier.

## Standardized Address Structure

```javascript
{
  street: String,           // "123 Main Street" or "Building A, Floor 2"
  city: String,             // "Gaza", "Ramallah", "Nablus"
  state: String,            // "Gaza Strip", "West Bank"
  zip_code: String,         // Postal code
  country: String,          // Default: "Palestine"
  full_address: String,     // Complete address as single string (optional)
  coordinates: {
    latitude: Number,       // -90 to 90
    longitude: Number       // -180 to 180
  }
}
```

## Models Using Address Schema

### 1. **Patient** (`models/Patient.js`)
```javascript
{
  full_name: { first, middle, last },
  identity_number: String,
  phone_number: String,
  address: {
    street: "15 Hospital Road",
    city: "Gaza",
    state: "Gaza Strip",
    zip_code: "00000",
    country: "Palestine",
    coordinates: {
      latitude: 31.5017,
      longitude: 34.4668
    }
  }
}
```

### 2. **Owner** (`models/Owner.js`)
```javascript
{
  name: { first, middle, last },
  identity_number: String,
  phone_number: String,
  address: {
    street: "789 Business Ave",
    city: "Ramallah",
    state: "West Bank",
    coordinates: {
      latitude: 31.9073,
      longitude: 35.2033
    }
  }
}
```

### 3. **Staff** (`models/Staff.js`)
```javascript
{
  full_name: { first, middle, last },
  identity_number: String,
  phone_number: String,
  address: {
    street: "456 Staff Street",
    city: "Nablus",
    coordinates: {
      latitude: 32.2211,
      longitude: 35.2544
    }
  }
}
```

### 4. **Order** (`models/Order.js`)
```javascript
{
  patient_id: ObjectId,
  address: {
    street: "Patient's delivery address",
    city: "Hebron",
    coordinates: {
      latitude: 31.5326,
      longitude: 35.0998
    }
  }
}
```

### 5. **LabBranch** (`models/LabBranch.js`)
```javascript
{
  branch_name: "Central Lab - Gaza",
  location: {
    street: "123 Medical Center Rd",
    city: "Gaza",
    state: "Gaza Strip",
    zip_code: "00000",
    country: "Palestine",
    full_address: "123 Medical Center Rd, Gaza, Gaza Strip",
    coordinates: {
      latitude: 31.5017,
      longitude: 34.4668
    }
  }
}
```

## Features

### Virtual Property: `formatted`
```javascript
// Automatically formats address for display
patient.address.formatted
// Returns: "15 Hospital Road, Gaza, Gaza Strip"
```

### Geospatial Queries
```javascript
// Find patients near a location
db.patients.find({
  'address.coordinates': {
    $near: {
      $geometry: {
        type: 'Point',
        coordinates: [34.4668, 31.5017] // [longitude, latitude]
      },
      $maxDistance: 5000 // 5km in meters
    }
  }
});
```

## Migration

### Running the Migration Script
To migrate existing data from old string addresses to the new schema:

```bash
node migrateAddresses.js
```

This will:
1. ✅ Convert all Patient addresses
2. ✅ Convert all Owner addresses  
3. ✅ Convert all Staff addresses
4. ✅ Convert all Order addresses
5. ✅ Update LabBranch `location.address` → `location.street`

**Before migration:**
```javascript
{ address: "123 Main Street, Gaza" }
```

**After migration:**
```javascript
{
  address: {
    street: "123 Main Street, Gaza",
    city: "",
    state: "",
    zip_code: "",
    country: "Palestine",
    full_address: "123 Main Street, Gaza",
    coordinates: {
      latitude: null,
      longitude: null
    }
  }
}
```

## API Updates

### Creating Records with New Address Format

**Patient Registration:**
```javascript
POST /api/patient/register
{
  "full_name": { "first": "Ahmad", "last": "Hassan" },
  "address": {
    "street": "15 Hospital Road",
    "city": "Gaza",
    "coordinates": {
      "latitude": 31.5017,
      "longitude": 34.4668
    }
  }
}
```

**Lab Branch Creation:**
```javascript
POST /api/branches
{
  "branch_name": "Central Lab - North",
  "location": {
    "street": "789 North Ave",
    "city": "Nablus",
    "state": "West Bank",
    "coordinates": {
      "latitude": 32.2211,
      "longitude": 35.2544
    }
  }
}
```

## Benefits

1. **Consistency**: Same structure across all models
2. **Geospatial Queries**: Easy distance calculations and location-based searches
3. **Better Data Quality**: Structured data instead of free-form strings
4. **Search Capability**: Can search by city, state, or coordinates
5. **Integration Ready**: Works seamlessly with LabBranch location system
6. **Backwards Compatible**: Migration script handles existing data

## Query Examples

### Find all patients in Gaza
```javascript
Patient.find({ 'address.city': 'Gaza' })
```

### Find staff near a location (within 10km)
```javascript
Staff.find({
  'address.coordinates.latitude': { $gte: 31.4, $lte: 31.6 },
  'address.coordinates.longitude': { $gte: 34.3, $lte: 34.6 }
})
```

### Get formatted address
```javascript
const patient = await Patient.findById(id);
console.log(patient.address.formatted);
// Output: "15 Hospital Road, Gaza, Gaza Strip"
```

## Palestine Major Cities Coordinates

For reference when adding location data:

| City | Latitude | Longitude |
|------|----------|-----------|
| Gaza | 31.5017 | 34.4668 |
| Ramallah | 31.9073 | 35.2033 |
| Nablus | 32.2211 | 35.2544 |
| Hebron | 31.5326 | 35.0998 |
| Bethlehem | 31.7054 | 35.2024 |
| Jenin | 32.4606 | 35.2969 |
| Tulkarm | 32.3103 | 35.0283 |
| Qalqilya | 32.1894 | 34.9703 |

## Notes

- All fields are optional except what's required by the specific model
- `coordinates` can be null if GPS data isn't available
- `full_address` is automatically generated by the virtual `formatted` property
- Old string addresses are preserved in `full_address` after migration
- Migration is idempotent - safe to run multiple times
