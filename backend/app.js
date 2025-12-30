const express = require('express');
const dotenv = require('dotenv');
const connectDB = require('./config/db');
const cronJobs = require('./cronJobs');
const logger = require('./utils/logger');
// const mongoSanitize = require('express-mongo-sanitize');

dotenv.config();

// Validate required environment variables
const requiredEnvVars = ['MONGO_URI', 'JWT_SECRET'];
const missingEnvVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingEnvVars.length > 0) {
  logger.error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
  logger.error('Please check your .env file');
  process.exit(1);
}

connectDB();

const app = express();

// Security middleware
const helmet = require('helmet');
const cors = require('cors');

app.use(helmet()); // Add security headers
app.use(cors({
  origin: ['http://localhost:5173', 'http://localhost:3000', /^http:\/\/localhost:\d+$/, /^http:\/\/192\.168\.1\.\d+:\d+$/, 'http://localhost:8080', 'http://127.0.0.1:8080'],
  credentials: true
}));

app.use(express.json());

// HTTP request logging
app.use(logger.httpLogger);

// Add request logging middleware
app.use((req, res, next) => {
  // console.log(`📨 REQUEST: ${req.method} ${req.path} - Headers: ${JSON.stringify(req.headers.authorization ? 'Bearer token present' : 'No auth')}`);
  next();
});

// NoSQL Injection Protection - sanitize all user input
// Temporarily disabled to fix "Cannot set property query" error
// app.use(mongoSanitize({
//   replaceWith: '_'
// }));

// Routes
app.use('/api/public', require('./routes/publicRoutes')); // Legacy public routes (kept for backwards compatibility)
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/owner', require('./routes/ownerRoutes'));
app.use('/api/patient', require('./routes/patientRoutes'));
app.use('/api/staff', require('./routes/staffRoutes'));
app.use('/api/doctor', require('./routes/doctorRoutes'));
app.use('/api/invoice', require('./routes/invoiceRoutes')); // Invoice & payment endpointsapp.use('/api/whatsapp', require('./routes/whatsappRoutes')); // WhatsApp webhook

// HL7 Integration Event Handlers
const Result = require('./models/Result');
const ResultComponent = require('./models/ResultComponent');
const OrderDetails = require('./models/OrderDetails');

// Handle ORU messages from HL7 server (device results)
process.on('hl7-result', async (data) => {
  try {
    const { resultInfo, observations } = data;

    // console.log(`📊 Processing HL7 ORU result for order: ${resultInfo.fillerOrderNumber}`);

    // Find the order detail
    const orderDetail = await OrderDetails.findById(resultInfo.fillerOrderNumber)
      .populate('test_id')
      .populate({
        path: 'order_id',
        populate: 'patient_id'
      });

    if (!orderDetail) {
      console.error(`❌ Order detail not found: ${resultInfo.fillerOrderNumber}`);
      return;
    }

    // Check if result already exists
    const existingResult = await Result.findOne({ detail_id: orderDetail._id });
    if (existingResult) {
      // console.log(`⚠️ Result already exists for order detail: ${orderDetail._id}`);
      return;
    }

    const test = orderDetail.test_id;
    const hasComponents = observations.length > 1;

    // Calculate abnormality
    let isAbnormal = false;
    let abnormalComponentsCount = 0;

    // Create result components
    const resultComponents = [];
    for (const obs of observations) {
      // Try to find corresponding test component by name or code
      let testComponent = await require('./models/TestComponent').findOne({
        test_id: test._id,
        $or: [
          { component_name: obs.name },
          { component_code: obs.code }
        ]
      });

      // If no component found and this is a single-value test, create a virtual component
      if (!testComponent && !hasComponents) {
        testComponent = {
          _id: null, // Virtual component
          component_name: obs.name || test.test_name,
          component_code: obs.code || test.test_code,
          units: obs.units,
          reference_range: obs.referenceRange
        };
      }

      if (testComponent) {
        const isComponentAbnormal = obs.isAbnormal || (obs.abnormalFlags && obs.abnormalFlags !== 'N' && obs.abnormalFlags !== '');
        if (isComponentAbnormal) {
          isAbnormal = true;
          abnormalComponentsCount++;
        }

        resultComponents.push({
          result_id: null, // Will be set after result creation
          component_id: testComponent._id,
          component_name: obs.name || testComponent.component_name,
          component_value: obs.value || obs.component_value || '',
          units: obs.units || testComponent.units,
          reference_range: obs.referenceRange || obs.reference_range || testComponent.reference_range,
          is_abnormal: isComponentAbnormal,
          remarks: obs.remarks || ''
        });
      }
    }

    // Create main result record
    const result = await Result.create({
      detail_id: orderDetail._id,
      staff_id: orderDetail.staff_id, // Use assigned staff
      has_components: hasComponents,
      result_value: hasComponents ? null : observations[0]?.value.toString(),
      units: hasComponents ? null : observations[0]?.units,
      reference_range: hasComponents ? null : observations[0]?.referenceRange,
      remarks: 'Generated via HL7 simulation',
      is_abnormal: isAbnormal,
      abnormal_components_count: abnormalComponentsCount
    });

    // Create result components if any (only for real components with valid IDs)
    const validResultComponents = resultComponents.filter(comp => comp.component_id !== null);
    if (validResultComponents.length > 0) {
      for (const comp of validResultComponents) {
        comp.result_id = result._id;
      }
      await ResultComponent.insertMany(validResultComponents);
    }

    // Log virtual components (those without database component_id)
    const virtualComponents = resultComponents.filter(comp => comp.component_id === null);
    if (virtualComponents.length > 0) {
      // console.log(`📝 Created ${virtualComponents.length} virtual result components (no matching test components in database)`);
    }

    // Update order detail status
    orderDetail.status = 'completed';
    orderDetail.result_id = result._id;
    await orderDetail.save();

    // console.log(`✅ HL7 Result processed: ${test.test_name} - ${isAbnormal ? 'ABNORMAL' : 'NORMAL'} (${abnormalComponentsCount} abnormal components)`);

    // TODO: Send notifications (patient, doctor, owner)

  } catch (error) {
    console.error('❌ Error processing HL7 result:', error.message);
  }
});

// Internal API for HL7 server communication
app.post('/api/internal/hl7-result', express.json(), async (req, res) => {
  try {
    const { resultInfo, observations } = req.body;

    // console.log(`📊 Processing HL7 ORU result for order: ${resultInfo.fillerOrderNumber || resultInfo.detailId}`);

    // Find the order detail
    const orderDetail = await require('./models/OrderDetails').findById(resultInfo.detailId || resultInfo.fillerOrderNumber)
      .populate('test_id')
      .populate({
        path: 'order_id',
        populate: 'patient_id'
      });

    if (!orderDetail) {
      console.error(`❌ Order detail not found: ${resultInfo.detailId || resultInfo.fillerOrderNumber}`);
      return res.status(404).json({ message: 'Order detail not found' });
    }

    // Check if result already exists
    const existingResult = await require('./models/Result').findOne({ detail_id: orderDetail._id });
    if (existingResult) {
      // console.log(`⚠️ Result already exists for order detail: ${orderDetail._id}`);
      return res.json({ message: 'Result already exists' });
    }

    const test = orderDetail.test_id;
    const hasComponents = observations.length > 1;

    // Calculate abnormality
    let isAbnormal = false;
    let abnormalComponentsCount = 0;

    // Create result components
    const resultComponents = [];
    for (const obs of observations) {
      // Try to find corresponding test component by name or code
      let testComponent = await require('./models/TestComponent').findOne({
        test_id: test._id,
        $or: [
          { component_name: obs.name },
          { component_code: obs.code }
        ]
      });

      // If no component found and this is a single-value test, create a virtual component
      if (!testComponent && !hasComponents) {
        testComponent = {
          _id: null, // Virtual component
          component_name: obs.name || test.test_name,
          component_code: obs.code || test.test_code,
          units: obs.units,
          reference_range: obs.referenceRange
        };
      }

      if (testComponent) {
        const isComponentAbnormal = obs.isAbnormal || (obs.abnormalFlags && obs.abnormalFlags !== 'N' && obs.abnormalFlags !== '');
        if (isComponentAbnormal) {
          isAbnormal = true;
          abnormalComponentsCount++;
        }

        resultComponents.push({
          result_id: null, // Will be set after result creation
          component_id: testComponent._id,
          component_name: obs.name || testComponent.component_name,
          component_value: obs.value || obs.component_value || '',
          units: obs.units || testComponent.units,
          reference_range: obs.referenceRange || obs.reference_range || testComponent.reference_range,
          is_abnormal: isComponentAbnormal,
          remarks: obs.remarks || ''
        });
      }
    }

    // Create main result record
    const Result = require('./models/Result');
    const result = await Result.create({
      detail_id: orderDetail._id,
      staff_id: orderDetail.staff_id, // Use assigned staff
      has_components: hasComponents,
      result_value: hasComponents ? null : observations[0]?.value.toString(),
      units: hasComponents ? null : observations[0]?.units,
      reference_range: hasComponents ? null : observations[0]?.referenceRange,
      remarks: 'Generated via HL7 simulation',
      is_abnormal: isAbnormal,
      abnormal_components_count: abnormalComponentsCount
    });

    // Create result components if any (only for real components with valid IDs)
    const validResultComponents = resultComponents.filter(comp => comp.component_id !== null);
    if (validResultComponents.length > 0) {
      for (const comp of validResultComponents) {
        comp.result_id = result._id;
      }
      await require('./models/ResultComponent').insertMany(validResultComponents);
    }

    // Log virtual components (those without database component_id)
    const virtualComponents = resultComponents.filter(comp => comp.component_id === null);
    if (virtualComponents.length > 0) {
      // console.log(`📝 Created ${virtualComponents.length} virtual result components (no matching test components in database)`);
    }

    // Update order detail status
    orderDetail.status = 'completed';
    orderDetail.result_id = result._id;
    await orderDetail.save();

    // console.log(`✅ HL7 Result processed: ${test.test_name} - ${isAbnormal ? 'ABNORMAL' : 'NORMAL'} (${abnormalComponentsCount} abnormal components)`);

    res.json({ message: 'HL7 result processed successfully' });

  } catch (error) {
    console.error('❌ Error processing HL7 result:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// Error Middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { 
    error: err.message, 
    stack: err.stack,
    url: req.url,
    method: req.method 
  });
  console.error('ERROR DETAILS:', err); // Add console log for debugging
  res.status(500).json({ message: err.message });
});

module.exports = app;
