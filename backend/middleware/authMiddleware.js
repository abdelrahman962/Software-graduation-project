const jwt = require('jsonwebtoken');

const authMiddleware = async (req, res, next) => {
  try {
    console.log('🔐 AUTH MIDDLEWARE: Request to', req.path);
    // Get token from header
    const token = req.header('Authorization')?.replace('Bearer ', '');
    console.log('🔐 AUTH MIDDLEWARE: Token present:', !!token);

    if (!token) {
      console.log('🔐 AUTH MIDDLEWARE: No token provided');
      return res.status(401).json({ message: 'No authentication token, access denied' });
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('🔐 AUTH MIDDLEWARE: Token verified for user:', decoded.username);
    
    // Attach user info to request
    req.user = decoded;
    req.user._id = decoded._id; // Normalize _id for consistency

    next();
  } catch (error) {
    console.log('🔐 AUTH MIDDLEWARE: Token verification failed:', error.message);
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Token has expired' });
    }
    res.status(401).json({ message: 'Token is not valid' });
  }
};

module.exports = authMiddleware;
