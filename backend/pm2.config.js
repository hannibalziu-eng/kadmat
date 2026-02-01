module.exports = {
  apps: [
    {
      name: 'kadmat-api',
      script: './src/index.js',
      instances: 'max',
      exec_mode: 'cluster',
      env: {
        PORT: 3000,
        NODE_ENV: 'production'
      }
    }
  ]
}
