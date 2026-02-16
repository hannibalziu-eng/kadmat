import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';

const swaggerOptions = {
    definition: {
        openapi: '3.0.0',
        info: {
            title: 'Kadmat API',
            version: '1.0.0',
            description: 'API documentation for Kadmat home services platform',
            contact: {
                name: 'Kadmat Support',
                email: 'support@kadmat.com'
            }
        },
        servers: [
            {
                url: 'http://localhost:3000',
                description: 'Development Server'
            },
            {
                url: 'https://api.kadmat.com',
                description: 'Production Server'
            }
        ],
        components: {
            securitySchemes: {
                bearerAuth: {
                    type: 'http',
                    scheme: 'bearer',
                    bearerFormat: 'JWT',
                    description: 'Enter your Supabase JWT token'
                }
            },
            schemas: {
                Job: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'uuid' },
                        customer_id: { type: 'string', format: 'uuid' },
                        technician_id: { type: 'string', format: 'uuid', nullable: true },
                        service_id: { type: 'string', format: 'uuid' },
                        status: {
                            type: 'string',
                            enum: ['pending', 'searching', 'accepted', 'price_pending', 'in_progress', 'pending_confirm', 'completed', 'rated', 'cancelled', 'no_technician_found']
                        },
                        lat: { type: 'number', format: 'double' },
                        lng: { type: 'number', format: 'double' },
                        address_text: { type: 'string' },
                        initial_price: { type: 'number' },
                        technician_price: { type: 'number', nullable: true },
                        customer_rating: { type: 'integer', minimum: 1, maximum: 5, nullable: true },
                        created_at: { type: 'string', format: 'date-time' }
                    }
                },
                User: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'uuid' },
                        email: { type: 'string', format: 'email' },
                        full_name: { type: 'string' },
                        phone: { type: 'string' },
                        user_type: { type: 'string', enum: ['customer', 'technician'] },
                        rating: { type: 'number' }
                    }
                },
                Error: {
                    type: 'object',
                    properties: {
                        success: { type: 'boolean', example: false },
                        error: {
                            type: 'object',
                            properties: {
                                code: { type: 'string' },
                                message: { type: 'string' }
                            }
                        }
                    }
                },
                Success: {
                    type: 'object',
                    properties: {
                        success: { type: 'boolean', example: true },
                        data: { type: 'object' },
                        message: { type: 'string' }
                    }
                }
            }
        },
        tags: [
            { name: 'Auth', description: 'Authentication endpoints' },
            { name: 'Jobs', description: 'Job management endpoints' },
            { name: 'Technician', description: 'Technician-specific endpoints' },
            { name: 'Wallet', description: 'Wallet and payment endpoints' },
            { name: 'Services', description: 'Service catalog endpoints' },
            { name: 'Health', description: 'Health check endpoints' }
        ]
    },
    apis: ['./src/routes/*.js', './src/controllers/*.js']
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

export const setupSwagger = (app) => {
    // Swagger JSON endpoint
    app.get('/api-docs/swagger.json', (req, res) => {
        res.setHeader('Content-Type', 'application/json');
        res.send(swaggerSpec);
    });

    // Swagger UI
    app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
        explorer: true,
        customCss: '.swagger-ui .topbar { display: none }',
        customSiteTitle: 'Kadmat API Documentation'
    }));
};

export default swaggerSpec;
