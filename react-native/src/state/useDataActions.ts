import { Dispatch, SetStateAction, useMemo } from 'react';
import { apiClient } from '../data/apiClient';
import { saveSessionToken } from '../data/storage';
import {
  AppUser,
  CouponView,
  NotificationItem,
  OrderView,
  ReferralView,
  SessionView,
  UsageSummary,
  UserSettings,
} from '../domain/models';

type Run = <T>(operation: () => Promise<T>) => Promise<T>;

export type DataActions = Readonly<{
  updateProfile: (patch: {
    displayName?: string;
    bio?: string;
    avatarUrl?: string | null;
  }) => Promise<boolean>;
  saveSettings: (patch: UserSettings) => Promise<boolean>;
  changePassword: (current: string, next: string) => Promise<boolean>;
  deleteAccount: (password: string) => Promise<boolean>;
  purchase: (planId: string) => Promise<boolean>;
  loadSessions: () => Promise<readonly SessionView[]>;
  revokeSession: (id: string) => Promise<boolean>;
  loadNotifications: () => Promise<readonly NotificationItem[]>;
  markNotificationsRead: () => Promise<void>;
  markNotificationRead: (id: string) => Promise<boolean>;
  deleteNotification: (id: string) => Promise<boolean>;
  loadOrders: () => Promise<readonly OrderView[]>;
  loadUsage: () => Promise<UsageSummary>;
  loadCoupons: () => Promise<readonly CouponView[]>;
  loadReferral: () => Promise<ReferralView>;
}>;

export function useDataActions(
  run: Run,
  setUser: Dispatch<SetStateAction<AppUser | null>>,
  user: AppUser | null,
): DataActions {
  return useMemo(() => ({
    updateProfile: async (patch: {
      displayName?: string;
      bio?: string;
      avatarUrl?: string | null;
    }) => {
      try { setUser(await run(() => apiClient.updateProfile(patch))); return true; }
      catch { return false; }
    },
    saveSettings: async (patch: UserSettings) => {
      try {
        const settings = await run(() => apiClient.saveSettings(patch));
        if (user) setUser({ ...user, settings });
        return true;
      } catch { return false; }
    },
    changePassword: async (current: string, next: string) => {
      try {
        await run(() => apiClient.changePassword(current, next));
        await saveSessionToken(null);
        setUser(null);
        return true;
      } catch { return false; }
    },
    deleteAccount: async (password: string) => {
      try {
        await run(() => apiClient.deleteAccount(password));
        await saveSessionToken(null);
        setUser(null);
        return true;
      } catch { return false; }
    },
    purchase: async (planId: string) => {
      try {
        await run(() => apiClient.purchase(planId));
        setUser((await run(apiClient.bootstrap)).user);
        return true;
      } catch { return false; }
    },
    loadSessions: () => run(apiClient.sessions),
    revokeSession: async (id: string) => {
      try { return (await run(() => apiClient.revokeSession(id))).revoked; }
      catch { return false; }
    },
    loadNotifications: () => run(apiClient.notifications),
    markNotificationsRead: async () => { await run(apiClient.readAllNotifications); },
    markNotificationRead: async (id: string) => {
      try { return (await run(() => apiClient.readNotification(id))).read; }
      catch { return false; }
    },
    deleteNotification: async (id: string) => {
      try { return (await run(() => apiClient.deleteNotification(id))).deleted; }
      catch { return false; }
    },
    loadOrders: () => run(apiClient.orders),
    loadUsage: () => run(apiClient.usage),
    loadCoupons: () => run(apiClient.coupons),
    loadReferral: () => run(apiClient.referral),
  }), [run, setUser, user]);
}
