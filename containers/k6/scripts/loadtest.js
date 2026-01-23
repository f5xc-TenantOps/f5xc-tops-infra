/**
 * K6 Load Test Script for TOPS Endpoints
 *
 * This script generates synthetic load against TOPS endpoints through a Tor proxy.
 * It uses configurable stages to ramp up/down virtual users and tracks custom metrics
 * for error rates and response times.
 *
 * Environment Variables:
 *   TARGET_URL - Base URL for the target service (default: http://localhost:8080)
 *
 * Usage:
 *   k6 run loadtest.js
 *   k6 run -e TARGET_URL=http://example.com loadtest.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 5 },   // Ramp up to 5 VUs
    { duration: '2m', target: 5 },    // Hold at 5 VUs
    { duration: '30s', target: 10 },  // Ramp up to 10 VUs
    { duration: '1m', target: 10 },   // Hold at 10 VUs
    { duration: '30s', target: 0 },   // Ramp down to 0 VUs
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests should complete in under 2s
    errors: ['rate<0.1'],              // Error rate should be less than 10%
  },
};

// Endpoints to test
const ENDPOINTS = [
  '/api/v1/health',
  '/api/v1/status',
];

/**
 * Default function executed by each virtual user
 */
export default function () {
  const targetUrl = __ENV.TARGET_URL || 'http://localhost:8080';
  const endpoint = ENDPOINTS[Math.floor(Math.random() * ENDPOINTS.length)];
  const url = `${targetUrl}${endpoint}`;

  const response = http.get(url);

  // Record custom metrics
  responseTime.add(response.timings.duration);

  // Check response
  const passed = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });

  // Track errors
  errorRate.add(!passed);

  // Random sleep between 1-3 seconds
  sleep(Math.random() * 2 + 1);
}

/**
 * Handle test summary and export results
 * @param {Object} data - Summary data from k6
 * @returns {Object} - Output destinations for summary
 */
export function handleSummary(data) {
  const summary = {
    totalRequests: data.metrics.http_reqs ? data.metrics.http_reqs.values.count : 0,
    failedRequests: data.metrics.http_req_failed ? data.metrics.http_req_failed.values.passes : 0,
    avgResponseTime: data.metrics.http_req_duration ? data.metrics.http_req_duration.values.avg : 0,
    p95ResponseTime: data.metrics.http_req_duration ? data.metrics.http_req_duration.values['p(95)'] : 0,
    errorRate: data.metrics.errors ? data.metrics.errors.values.rate : 0,
  };

  console.log('=== Load Test Summary ===');
  console.log(`Total Requests: ${summary.totalRequests}`);
  console.log(`Failed Requests: ${summary.failedRequests}`);
  console.log(`Average Response Time: ${summary.avgResponseTime.toFixed(2)}ms`);
  console.log(`P95 Response Time: ${summary.p95ResponseTime.toFixed(2)}ms`);
  console.log(`Error Rate: ${(summary.errorRate * 100).toFixed(2)}%`);

  return {
    '/tmp/results.json': JSON.stringify(data, null, 2),
  };
}
