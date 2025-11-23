const mongoose = require('mongoose');

const labBranchSchema = new mongoose.Schema({
  owner_id: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'LabOwner', 
    required: true 
  },
  branch_name: { 
    type: String, 
    required: true 
  },
  branch_code: { 
    type: String, 
    required: true,
    unique: true 
  },
  location: {
    street: { 
      type: String, 
      required: true,
      trim: true
    },
    city: { 
      type: String, 
      required: true,
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
        required: true,
        min: -90,
        max: 90
      },
      longitude: { 
        type: Number, 
        required: true,
        min: -180,
        max: 180
      }
    }
  },
  contact: {
    phone: { 
      type: String, 
      required: true 
    },
    email: { 
      type: String 
    },
    fax: { 
      type: String 
    }
  },
  operating_hours: {
    monday: { open: String, close: String },
    tuesday: { open: String, close: String },
    wednesday: { open: String, close: String },
    thursday: { open: String, close: String },
    friday: { open: String, close: String },
    saturday: { open: String, close: String },
    sunday: { open: String, close: String }
  },
  services_offered: [{
    type: String
  }],
  is_active: { 
    type: Boolean, 
    default: true 
  },
  created_at: { 
    type: Date, 
    default: Date.now 
  }
}, {
  timestamps: true
});

// Index for geospatial queries
labBranchSchema.index({ 'location.coordinates': '2dsphere' });

// Method to calculate distance from a point (in kilometers)
labBranchSchema.methods.getDistanceFrom = function(latitude, longitude) {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(latitude - this.location.coordinates.latitude);
  const dLon = toRad(longitude - this.location.coordinates.longitude);
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(this.location.coordinates.latitude)) * 
    Math.cos(toRad(latitude)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

function toRad(degrees) {
  return degrees * (Math.PI / 180);
}

module.exports = mongoose.model('LabBranch', labBranchSchema);
