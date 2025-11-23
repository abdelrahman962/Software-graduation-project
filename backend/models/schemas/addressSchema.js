const mongoose = require('mongoose');

// Standardized address schema for consistent location data across all models
const addressSchema = new mongoose.Schema({
  street: { 
    type: String,
    trim: true
  },
  city: { 
    type: String,
    trim: true
  },
  state: { 
    type: String,
    trim: true
  },
  zip_code: { 
    type: String,
    trim: true
  },
  country: { 
    type: String,
    default: 'Palestine',
    trim: true
  },
  full_address: {
    type: String,
    trim: true
  },
  coordinates: {
    latitude: { 
      type: Number,
      min: -90,
      max: 90
    },
    longitude: { 
      type: Number,
      min: -180,
      max: 180
    }
  }
}, { _id: false });

// Virtual to get formatted address
addressSchema.virtual('formatted').get(function() {
  if (this.full_address) return this.full_address;
  
  const parts = [];
  if (this.street) parts.push(this.street);
  if (this.city) parts.push(this.city);
  if (this.state) parts.push(this.state);
  if (this.zip_code) parts.push(this.zip_code);
  if (this.country && this.country !== 'Palestine') parts.push(this.country);
  
  return parts.join(', ') || 'No address provided';
});

module.exports = addressSchema;
