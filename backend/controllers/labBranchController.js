const LabBranch = require('../models/LabBranch');
const Owner = require('../models/Owner');

// Create a new branch
exports.createBranch = async (req, res, next) => {
  try {
    const { 
      branch_name, 
      branch_code, 
      location, 
      contact, 
      operating_hours, 
      services_offered 
    } = req.body;

    // Verify owner exists and is active
    const owner = await Owner.findById(req.user._id);
    if (!owner || !owner.is_active) {
      return res.status(403).json({ message: 'Owner account not active' });
    }

    const branch = new LabBranch({
      owner_id: req.user._id,
      branch_name,
      branch_code,
      location,
      contact,
      operating_hours,
      services_offered
    });

    await branch.save();
    res.status(201).json({ 
      message: 'Branch created successfully', 
      branch 
    });
  } catch (error) {
    next(error);
  }
};

// Get all branches for logged-in owner
exports.getOwnerBranches = async (req, res, next) => {
  try {
    const branches = await LabBranch.find({ 
      owner_id: req.user._id,
      is_active: true 
    });
    
    res.json({ branches, count: branches.length });
  } catch (error) {
    next(error);
  }
};

// Get single branch details
exports.getBranchById = async (req, res, next) => {
  try {
    const branch = await LabBranch.findOne({
      _id: req.params.id,
      owner_id: req.user._id
    }).populate('owner_id', 'name email phone_number');

    if (!branch) {
      return res.status(404).json({ message: 'Branch not found' });
    }

    res.json({ branch });
  } catch (error) {
    next(error);
  }
};

// Update branch
exports.updateBranch = async (req, res, next) => {
  try {
    const branch = await LabBranch.findOneAndUpdate(
      { _id: req.params.id, owner_id: req.user._id },
      req.body,
      { new: true, runValidators: true }
    );

    if (!branch) {
      return res.status(404).json({ message: 'Branch not found' });
    }

    res.json({ message: 'Branch updated successfully', branch });
  } catch (error) {
    next(error);
  }
};

// Delete (deactivate) branch
exports.deleteBranch = async (req, res, next) => {
  try {
    const branch = await LabBranch.findOneAndUpdate(
      { _id: req.params.id, owner_id: req.user._id },
      { is_active: false },
      { new: true }
    );

    if (!branch) {
      return res.status(404).json({ message: 'Branch not found' });
    }

    res.json({ message: 'Branch deactivated successfully' });
  } catch (error) {
    next(error);
  }
};

// Find nearest branches (PUBLIC - for patients)
exports.findNearestBranches = async (req, res, next) => {
  try {
    const { latitude, longitude, maxDistance = 50, limit = 10 } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({ 
        message: 'Latitude and longitude are required' 
      });
    }

    const lat = parseFloat(latitude);
    const lon = parseFloat(longitude);

    // Find branches using MongoDB geospatial query
    const branches = await LabBranch.aggregate([
      {
        $geoNear: {
          near: {
            type: 'Point',
            coordinates: [lon, lat]
          },
          distanceField: 'distance',
          maxDistance: parseFloat(maxDistance) * 1000, // Convert km to meters
          spherical: true,
          query: { is_active: true }
        }
      },
      {
        $limit: parseInt(limit)
      },
      {
        $lookup: {
          from: 'labowners',
          localField: 'owner_id',
          foreignField: '_id',
          as: 'owner'
        }
      },
      {
        $unwind: '$owner'
      },
      {
        $match: {
          'owner.is_active': true,
          'owner.status': 'approved'
        }
      },
      {
        $project: {
          branch_name: 1,
          branch_code: 1,
          location: 1,
          contact: 1,
          operating_hours: 1,
          services_offered: 1,
          distance: { $divide: ['$distance', 1000] }, // Convert to km
          'owner.name': 1,
          'owner.phone_number': 1,
          'owner.email': 1
        }
      }
    ]);

    res.json({ 
      branches, 
      count: branches.length,
      searchLocation: { latitude: lat, longitude: lon }
    });
  } catch (error) {
    next(error);
  }
};

// Get all available labs (PUBLIC - for patients to browse all labs)
exports.getAllAvailableLabs = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, city, state, services, search } = req.query;
    
    let query = { is_active: true };
    
    // Filter by city
    if (city) {
      query['location.city'] = new RegExp(city, 'i');
    }
    
    // Filter by state
    if (state) {
      query['location.state'] = new RegExp(state, 'i');
    }
    
    // Filter by services offered
    if (services) {
      query.services_offered = { 
        $in: services.split(',').map(s => s.trim()) 
      };
    }
    
    // Search by branch name or location
    if (search) {
      query.$or = [
        { branch_name: new RegExp(search, 'i') },
        { 'location.city': new RegExp(search, 'i') },
        { 'location.street': new RegExp(search, 'i') }
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const branches = await LabBranch.find(query)
      .populate('owner_id', 'name phone_number email is_active status')
      .skip(skip)
      .limit(parseInt(limit))
      .sort({ created_at: -1 });

    // Filter to only show branches with active, approved owners
    const activeBranches = branches.filter(
      b => b.owner_id?.is_active && b.owner_id?.status === 'approved'
    );
    
    // Get total count for pagination
    const totalCount = await LabBranch.countDocuments(query);

    res.json({ 
      branches: activeBranches, 
      count: activeBranches.length,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        pages: Math.ceil(totalCount / parseInt(limit))
      }
    });
  } catch (error) {
    next(error);
  }
};

// Search branches by city or area (kept for backwards compatibility)
exports.searchBranches = async (req, res, next) => {
  try {
    const { city, state, services } = req.query;
    
    let query = { is_active: true };
    
    if (city) {
      query['location.city'] = new RegExp(city, 'i');
    }
    
    if (state) {
      query['location.state'] = new RegExp(state, 'i');
    }
    
    if (services) {
      query.services_offered = { 
        $in: services.split(',').map(s => s.trim()) 
      };
    }

    const branches = await LabBranch.find(query)
      .populate('owner_id', 'name phone_number email is_active status')
      .limit(50);

    // Filter to only show branches with active, approved owners
    const activeBranches = branches.filter(
      b => b.owner_id?.is_active && b.owner_id?.status === 'approved'
    );

    res.json({ 
      branches: activeBranches, 
      count: activeBranches.length 
    });
  } catch (error) {
    next(error);
  }
};

// Get all branches (Admin only)
exports.getAllBranches = async (req, res, next) => {
  try {
    const branches = await LabBranch.find()
      .populate('owner_id', 'name email phone_number is_active status')
      .sort({ created_at: -1 });

    res.json({ branches, count: branches.length });
  } catch (error) {
    next(error);
  }
};
