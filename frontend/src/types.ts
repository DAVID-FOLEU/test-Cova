export type TaskStatus = 'PENDING' | 'IN_PROGRESS' | 'COMPLETED';

export interface UserCova {
  userId: number;
  email: string;
  token: string;
  nom?: string;
  prenom?: string;
}

export interface Task {
  id?: number;
  title: string;
  description: string;
  status: TaskStatus;
  createdAt?: string;
  updatedAt?: string;
}