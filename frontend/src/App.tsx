import React, { useState, useEffect } from 'react';
import type { UserCova, Task } from './types';
import { 
  CheckCircle2, 
  Circle, 
  Trash2, 
  LogOut, 
  Plus, 
  Check, 
  Clock, 
  Eye, 
  EyeOff,
  Loader2,
  Edit2,
  X,
  PlayCircle
} from 'lucide-react';

const API_BASE = process.env.REACT_APP_API_URL || import.meta.env.VITE_API_BASE_URL || '';
const API_URL = `${API_BASE}/api`;
// const API_URL = '/api';

const apiFetch = (input: RequestInfo | URL, init: RequestInit = {}) => {
  const token = localStorage.getItem('cova_token');
  const headers = new Headers(init.headers);
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  return fetch(input, { ...init, headers });
};

export default function App() {
  const [user, setUser] = useState<UserCova | null>(() => {
    const saved = localStorage.getItem('cova_user');
    return saved ? JSON.parse(saved) : null;
  });

  // 1. Définition du type pour les filtres
type FilterStatus = 'ALL' | 'PENDING' | 'IN_PROGRESS' | 'COMPLETED';

  const [isRegister, setIsRegister] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [authForm, setAuthForm] = useState({ nom: '', prenom: '', email: '', password: '' });
  const [authError, setAuthError] = useState('');
  const [authLoading, setAuthLoading] = useState(false);

  const [tasks, setTasks] = useState<Task[]>([]);
  const [filterStatus, setFilterStatus] = useState<'ALL' | 'PENDING' | 'IN_PROGRESS' | 'COMPLETED'>('ALL');
  
  const [newTask, setNewTask] = useState({ title: '', description: '', status: 'PENDING' as const });
  const [isCreating, setIsCreating] = useState(false);

  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const [isUpdating, setIsUpdating] = useState(false);

  const [loadingTaskIds, setLoadingTaskIds] = useState<{ [key: number]: string }>({});

  const userId = user?.userId;

  // --- Chargement des Tâches ---
  useEffect(() => {
    if (!userId) return;

    let isMounted = true;

    const loadTasks = async () => {
      try {
        const res = await apiFetch(`${API_URL}/tasks?userId=${userId}`);
        if (res.ok && isMounted) {
          const data: Task[] = await res.json();
          setTasks(data);
        }
      } catch (err) {
        console.error('Erreur chargement tâches:', err);
      }
    };

    loadTasks();

    return () => {
      isMounted = false;
    };
  }, [userId]);

  const refreshTasks = async () => {
    if (!userId) return;
    try {
      const res = await apiFetch(`${API_URL}/tasks?userId=${userId}`);
      if (res.ok) {
        const data: Task[] = await res.json();
        setTasks(data);
      }
    } catch (err) {
      console.error('Erreur rafraîchissement tâches:', err);
    }
  };

  const setTaskLoading = (id: number, action: string | null) => {
    setLoadingTaskIds((prev) => {
      if (action === null) {
        const next = { ...prev };
        delete next[id];
        return next;
      }
      return { ...prev, [id]: action };
    });
  };

  // --- Authentification ---
  const handleAuthSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setAuthError('');
    setAuthLoading(true);
    const endpoint = isRegister ? '/auth/register' : '/auth/login';

    try {
      const res = await apiFetch(`${API_URL}${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(authForm),
      });

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(errText || 'Erreur lors de l\'authentification');
      }

      if (isRegister) {
        alert('Inscription réussie ! Vous pouvez maintenant vous connecter.');
        setIsRegister(false);
        setAuthForm({ nom: '', prenom: '', email: authForm.email, password: '' });
      } else {
        const data: UserCova = await res.json();
        setUser(data);
        localStorage.setItem('cova_user', JSON.stringify(data));
        localStorage.setItem('cova_token', data.token);
      }
    } catch (err) {
      const error = err as Error;
      setAuthError(error.message);
    } finally {
      setAuthLoading(false);
    }
  };

  const handleLogout = () => {
    setUser(null);
    localStorage.removeItem('cova_user');
    localStorage.removeItem('cova_token');
  };

  // --- Actions Tâches ---
  const handleCreateTask = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTask.title.trim() || !userId) return;

    setIsCreating(true);
    try {
      const res = await apiFetch(`${API_URL}/tasks?userId=${userId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newTask),
      });

      if (res.ok) {
        setNewTask({ title: '', description: '', status: 'PENDING' });
        await refreshTasks();
      }
    } catch (err) {
      console.error('Erreur création tâche:', err);
    } finally {
      setIsCreating(false);
    }
  };

  const handleUpdateTaskSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingTask || !editingTask.id || !userId) return;

    setIsUpdating(true);
    try {
      const res = await apiFetch(`${API_URL}/tasks/${editingTask.id}?userId=${userId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(editingTask),
      });

      if (res.ok) {
        setEditingTask(null);
        await refreshTasks();
      }
    } catch (err) {
      console.error('Erreur édition tâche:', err);
    } finally {
      setIsUpdating(false);
    }
  };

  const handleStatusChange = async (task: Task, newStatus: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED') => {
    if (!task.id || !userId) return;
    setTaskLoading(task.id, 'status');

    try {
      const res = await apiFetch(`${API_URL}/tasks/${task.id}?userId=${userId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...task, status: newStatus }),
      });
      if (res.ok) await refreshTasks();
    } catch (err) {
      console.error('Erreur modification statut:', err);
    } finally {
      setTaskLoading(task.id, null);
    }
  };

  const handleDeleteTask = async (id?: number) => {
    if (!id || !userId) return;
    setTaskLoading(id, 'delete');

    try {
      const res = await apiFetch(`${API_URL}/tasks/${id}?userId=${userId}`, { method: 'DELETE' });
      if (res.ok) await refreshTasks();
    } catch (err) {
      console.error('Erreur suppression tâche:', err);
    } finally {
      setTaskLoading(id, null);
    }
  };

  const filteredTasks = tasks.filter((task) => {
    if (filterStatus === 'ALL') return true;
    return task.status === filterStatus;
  });

  // --- Écran de Connexion / Inscription ---
  if (!user) {
    return (
      <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
        <div className="bg-slate-800 text-white p-6 sm:p-8 rounded-2xl shadow-xl w-full max-w-md border border-slate-700">
          <h2 className="text-2xl font-bold mb-6 text-center text-indigo-400">
            {isRegister ? 'Inscription Cova' : 'Connexion Cova'}
          </h2>

          {authError && (
            <div className="bg-red-500/10 border border-red-500/50 text-red-400 p-3 rounded-lg text-sm mb-4">
              {authError}
            </div>
          )}

          <form onSubmit={handleAuthSubmit} className="space-y-4">
            {isRegister && (
              <>
                <input
                  type="text"
                  placeholder="Nom"
                  value={authForm.nom}
                  onChange={(e) => setAuthForm({ ...authForm, nom: e.target.value })}
                  required
                  className="w-full px-4 py-3 bg-slate-900 border border-slate-700 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none transition text-sm"
                />
                <input
                  type="text"
                  placeholder="Prénom"
                  value={authForm.prenom}
                  onChange={(e) => setAuthForm({ ...authForm, prenom: e.target.value })}
                  required
                  className="w-full px-4 py-3 bg-slate-900 border border-slate-700 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none transition text-sm"
                />
              </>
            )}
            <input
              type="email"
              placeholder="Email"
              value={authForm.email}
              onChange={(e) => setAuthForm({ ...authForm, email: e.target.value })}
              required
              className="w-full px-4 py-3 bg-slate-900 border border-slate-700 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none transition text-sm"
            />
            
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                placeholder="Mot de passe"
                value={authForm.password}
                onChange={(e) => setAuthForm({ ...authForm, password: e.target.value })}
                required
                className="w-full px-4 py-3 bg-slate-900 border border-slate-700 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none transition pr-12 text-sm"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-200 p-1 transition"
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>

            <button
              type="submit"
              disabled={authLoading}
              className="w-full py-3 bg-indigo-600 hover:bg-indigo-500 font-semibold rounded-lg transition duration-200 flex items-center justify-center gap-2 disabled:opacity-50 text-sm"
            >
              {authLoading && <Loader2 size={18} className="animate-spin" />}
              {isRegister ? "S'inscrire" : 'Se connecter'}
            </button>
          </form>

          <button
            onClick={() => {
              setIsRegister(!isRegister);
              setAuthError('');
            }}
            className="w-full text-center text-sm text-slate-400 hover:text-indigo-400 mt-6 transition"
          >
            {isRegister ? 'Déjà un compte ? Se connecter' : "Pas de compte ? S'inscrire"}
          </button>
        </div>
      </div>
    );
  }

  // --- Écran Principal ---
  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4 sm:p-6">
      <div className="max-w-3xl mx-auto space-y-6 sm:space-y-8">
        
        {/* Header Responsive */}
        <header className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-slate-900 p-4 sm:p-6 rounded-2xl border border-slate-800">
          <div>
            <h1 className="text-lg sm:text-xl font-bold text-indigo-400">Task Manager Cova</h1>
            <p className="text-xs sm:text-sm text-slate-400">{user.email}</p>
          </div>
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 px-3 sm:px-4 py-2 bg-red-500/10 text-red-400 hover:bg-red-500/20 border border-red-500/20 rounded-lg transition text-xs sm:text-sm w-full sm:w-auto justify-center"
          >
            <LogOut size={16} /> Déconnexion
          </button>
        </header>

        {/* Formulaire de création */}
        <form onSubmit={handleCreateTask} className="bg-slate-900 p-4 sm:p-6 rounded-2xl border border-slate-800 space-y-4">
          <h3 className="text-base sm:text-lg font-semibold flex items-center gap-2">
            <Plus className="text-indigo-400" size={20} /> Nouvelle tâche
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <input
              type="text"
              placeholder="Titre de la tâche"
              value={newTask.title}
              onChange={(e) => setNewTask({ ...newTask, title: e.target.value })}
              required
              className="px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-sm"
            />
            <input
              type="text"
              placeholder="Description (optionnelle)"
              value={newTask.description}
              onChange={(e) => setNewTask({ ...newTask, description: e.target.value })}
              className="px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-sm"
            />
          </div>
          <button
            type="submit"
            disabled={isCreating}
            className="w-full md:w-auto px-6 py-2.5 bg-indigo-600 hover:bg-indigo-500 font-medium rounded-lg transition flex items-center justify-center gap-2 disabled:opacity-50 text-sm"
          >
            {isCreating && <Loader2 size={16} className="animate-spin" />}
            Ajouter la tâche
          </button>
        </form>

        {/* Modal / Formulaire d'édition */}
        {editingTask && (
          <form onSubmit={handleUpdateTaskSubmit} className="bg-slate-900 p-4 sm:p-6 rounded-2xl border border-indigo-500/30 space-y-4 relative">
            <div className="flex justify-between items-center">
              <h3 className="text-base sm:text-lg font-semibold flex items-center gap-2 text-indigo-400">
                <Edit2 size={18} /> Modifier la tâche
              </h3>
              <button
                type="button"
                onClick={() => setEditingTask(null)}
                className="text-slate-400 hover:text-slate-200 p-1"
              >
                <X size={18} />
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <input
                type="text"
                placeholder="Titre"
                value={editingTask.title}
                onChange={(e) => setEditingTask({ ...editingTask, title: e.target.value })}
                required
                className="px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-sm"
              />
              <input
                type="text"
                placeholder="Description"
                value={editingTask.description || ''}
                onChange={(e) => setEditingTask({ ...editingTask, description: e.target.value })}
                className="px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-sm"
              />
            </div>
            <div className="flex gap-2 justify-end">
              <button
                type="button"
                onClick={() => setEditingTask(null)}
                className="px-4 py-2 bg-slate-800 text-slate-300 rounded-lg hover:bg-slate-700 text-sm"
              >
                Annuler
              </button>
              <button
                type="submit"
                disabled={isUpdating}
                className="px-5 py-2 bg-indigo-600 hover:bg-indigo-500 font-medium rounded-lg transition flex items-center gap-2 disabled:opacity-50 text-sm"
              >
                {isUpdating && <Loader2 size={16} className="animate-spin" />}
                Enregistrer
              </button>
            </div>
          </form>
        )}

        {/* Filtres par onglets */}
       

      <div className="flex flex-wrap gap-2 border-b border-slate-800 pb-3">
        {[
          { key: 'ALL', label: 'Toutes' },
          { key: 'PENDING', label: 'En attente' },
          { key: 'IN_PROGRESS', label: 'En cours' },
          { key: 'COMPLETED', label: 'Terminées' },
        ].map((tab) => (
          <button
            key={tab.key}
            onClick={() => setFilterStatus(tab.key as FilterStatus)}
            className={`px-3.5 py-1.5 rounded-lg text-xs sm:text-sm font-medium transition ${
              filterStatus === tab.key
                ? 'bg-indigo-600 text-white'
                : 'bg-slate-900 text-slate-400 hover:bg-slate-800 hover:text-slate-200'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

        {/* Liste des Tâches */}
        <div className="space-y-3">
          {filteredTasks.length === 0 ? (
            <div className="text-center py-12 bg-slate-900/50 rounded-2xl border border-slate-800 text-slate-500 text-sm">
              Aucune tâche ne correspond à ce filtre.
            </div>
          ) : (
            filteredTasks.map((task) => {
              const taskId = task.id!;
              const isLoading = !!loadingTaskIds[taskId];
              const currentAction = loadingTaskIds[taskId];

              return (
                <div
                  key={taskId}
                  className={`p-4 sm:p-5 bg-slate-900 rounded-xl border flex flex-col sm:flex-row sm:items-center justify-between gap-4 transition ${
                    task.status === 'COMPLETED' ? 'border-emerald-500/20 opacity-75' : 'border-slate-800'
                  }`}
                >
                  <div className="flex items-start gap-3 sm:gap-4">
                    <div className="mt-1">
                      {task.status === 'COMPLETED' && <CheckCircle2 className="text-emerald-400" size={20} />}
                      {task.status === 'IN_PROGRESS' && <PlayCircle className="text-blue-400" size={20} />}
                      {task.status === 'PENDING' && <Circle className="text-amber-400" size={20} />}
                    </div>

                    <div>
                      <h4 className={`font-medium text-sm sm:text-base ${task.status === 'COMPLETED' ? 'line-through text-slate-500' : 'text-slate-100'}`}>
                        {task.title}
                      </h4>
                      {task.description && <p className="text-xs sm:text-sm text-slate-400 mt-1">{task.description}</p>}
                      
                      {/* Badge de statut */}
                      <span
                        className={`inline-flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-full mt-2 font-medium border ${
                          task.status === 'COMPLETED'
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                            : task.status === 'IN_PROGRESS'
                            ? 'bg-blue-500/10 text-blue-400 border-blue-500/20'
                            : 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                        }`}
                      >
                        <span>
                          {task.status === 'COMPLETED' ? (
                            <Check key="icon-completed" size={12} />
                          ) : task.status === 'IN_PROGRESS' ? (
                            <PlayCircle key="icon-progress" size={12} />
                          ) : (
                            <Clock key="icon-pending" size={12} />
                          )}
                        </span>
                        {task.status === 'COMPLETED' ? 'Terminée' : task.status === 'IN_PROGRESS' ? 'En cours' : 'En attente'}
                      </span>
                    </div>
                  </div>

                  {/* Boutons d'actions */}
                  <div className="flex items-center gap-2 self-end sm:self-center border-t sm:border-t-0 pt-3 sm:pt-0 border-slate-800 w-full sm:w-auto justify-end">
                    
                    {/* Boutons de changement rapide de statut */}
                    {task.status !== 'PENDING' && (
                      <button
                        onClick={() => handleStatusChange(task, 'PENDING')}
                        disabled={isLoading}
                        title="Passer à En attente"
                        className="px-2.5 py-1.5 bg-amber-500/10 text-amber-400 hover:bg-amber-500/20 border border-amber-500/20 rounded-lg text-xs font-medium flex items-center gap-1 transition disabled:opacity-50"
                      >
                          {isLoading && currentAction === 'status' ? (
                            <span key="loading-status" className="inline-flex items-center">
                              <Loader2 size={12} className="animate-spin" />
                            </span>
                          ) : (
                            <span key="idle-status">
                              Attente
                            </span>
                          )}                      </button>
                    )}

                    {task.status !== 'IN_PROGRESS' && (
                      <button
                        onClick={() => handleStatusChange(task, 'IN_PROGRESS')}
                        disabled={isLoading}
                        title="Passer à En cours"
                        className="px-2.5 py-1.5 bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 border border-blue-500/20 rounded-lg text-xs font-medium flex items-center gap-1 transition disabled:opacity-50"
                      >
                        {isLoading && currentAction === 'status' ? (
                          <span key="loading-in-progress" className="inline-flex items-center">
                            <Loader2 size={12} className="animate-spin" />
                          </span>
                        ) : (
                          <span key="idle-in-progress">En cours</span>
                        )}
                      </button>
                    )}

                    {task.status !== 'COMPLETED' && (
                      <button
                        onClick={() => handleStatusChange(task, 'COMPLETED')}
                        disabled={isLoading}
                        title="Marquer comme Terminée"
                        className="px-2.5 py-1.5 bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20 border border-emerald-500/20 rounded-lg text-xs font-medium flex items-center gap-1 transition disabled:opacity-50"
                      >
                        {isLoading && currentAction === 'status' ? (
                          <span key="loading-completed" className="inline-flex items-center">
                            <Loader2 size={12} className="animate-spin" />
                          </span>
                        ) : (
                          <span key="idle-completed">Terminer</span>
                        )}
                      </button>
                    )}

                    {/* Modifier */}
                    <button
                      onClick={() => setEditingTask(task)}
                      disabled={isLoading}
                      className="p-2 text-slate-400 hover:text-indigo-400 hover:bg-indigo-500/10 rounded-lg transition"
                      title="Modifier"
                    >
                      <Edit2 size={16} />
                    </button>

                    {/* Supprimer */}
                    <button
                      onClick={() => handleDeleteTask(taskId)}
                      disabled={isLoading}
                      className="p-2 text-slate-500 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition disabled:opacity-50"
                      title="Supprimer"
                    >
                     {isLoading && currentAction === 'delete' ? (
                        <span key="deleting-loader" className="inline-flex items-center justify-center">
                          <Loader2 size={16} className="animate-spin text-red-400" />
                        </span>
                      ) : (
                        <span key="delete-icon" className="inline-flex items-center justify-center">
                          <Trash2 size={16} />
                        </span>
                      )}
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}