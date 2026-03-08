import { request, APIRequestContext, expect } from '@playwright/test';

export type LoginPayload = {
  email: string;
  password: string;
};

export class KadmatApiClient {
  readonly baseUrl: string;
  private context?: APIRequestContext;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
  }

  async init(): Promise<void> {
    this.context = await request.newContext({
      baseURL: this.baseUrl,
      extraHTTPHeaders: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
    });
  }

  async dispose(): Promise<void> {
    await this.context?.dispose();
    this.context = undefined;
  }

  private get ctx(): APIRequestContext {
    if (!this.context) {
      throw new Error('KadmatApiClient is not initialized. Call init() first.');
    }
    return this.context;
  }

  async login(payload: LoginPayload): Promise<string> {
    const response = await this.ctx.post('auth/login', { data: payload });
    expect(response.ok(), `Login failed: ${response.status()} ${response.statusText()}`).toBeTruthy();
    const body = await response.json();
    const token = body?.token;
    if (!token) {
      throw new Error('Login succeeded but token is missing in response body.');
    }
    return token;
  }

  async getMeJobs(token: string): Promise<unknown> {
    const response = await this.ctx.get('jobs/my-jobs', {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.ok(), `GET /jobs/my-jobs failed with status ${response.status()}`).toBeTruthy();
    return response.json();
  }

  async getTechnicianProfile(token: string, technicianId: string): Promise<unknown> {
    const response = await this.ctx.get(`technician/${encodeURIComponent(technicianId)}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.ok(), `GET /technician/:id failed with status ${response.status()}`).toBeTruthy();
    return response.json();
  }

  async getWallet(token: string): Promise<unknown> {
    const response = await this.ctx.get('wallet', {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.ok(), `GET /wallet failed with status ${response.status()}`).toBeTruthy();
    return response.json();
  }

  async getNotifications(token: string): Promise<unknown> {
    const response = await this.ctx.get('notifications', {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.ok(), `GET /notifications failed with status ${response.status()}`).toBeTruthy();
    return response.json();
  }

  async getMessageConversations(token: string): Promise<unknown> {
    const response = await this.ctx.get('messages/conversations', {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.ok(), `GET /messages/conversations failed with status ${response.status()}`).toBeTruthy();
    return response.json();
  }
}
