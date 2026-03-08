import { useState, useRef } from 'react';
import { Moon, Sun, Download, Upload, Trash2, Plus, RefreshCw, FolderOpen, CloudOff } from 'lucide-react';
import { useAppStore } from '../store/StoreContext';
import { Card } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { exportToCSV, exportToJSON, importFromJSON } from '../utils/export';
import { CURRENCIES } from '../store/defaults';
import { isElectronApp, pickSyncFolder } from '../store/fileSync';
import type { SyncProvider } from '../types';

const CATEGORY_COLORS = [
  'bg-red-500', 'bg-orange-500', 'bg-amber-500', 'bg-yellow-500', 'bg-lime-500',
  'bg-green-500', 'bg-emerald-500', 'bg-teal-500', 'bg-cyan-500', 'bg-sky-500',
  'bg-blue-500', 'bg-indigo-500', 'bg-violet-500', 'bg-purple-500', 'bg-fuchsia-500',
  'bg-pink-500', 'bg-rose-500', 'bg-gray-500', 'bg-slate-500',
];

const EMOJI_LIST = ['🍽️','🛒','🚗','🏠','💡','🏥','🎬','🛍️','📚','✈️','🛡️','📱','💆','🎁','📦','💼','💻','📈','💰','🎮','🍺','☕','🚀','💊','🐾','🌱'];

function AddCategoryForm({ onClose }: { onClose: () => void }) {
  const { addCategory } = useAppStore();
  const [name, setName] = useState('');
  const [icon, setIcon] = useState('📦');
  const [color, setColor] = useState('bg-indigo-500');
  const [type, setType] = useState<'expense' | 'income' | 'both'>('expense');
  const [error, setError] = useState('');

  const handleSave = () => {
    if (!name.trim()) { setError('Name is required'); return; }
    addCategory({ name: name.trim(), icon, color, type });
    onClose();
  };

  return (
    <div className="space-y-4">
      <Input label="Category name" placeholder="e.g. Sports" value={name} onChange={e => { setName(e.target.value); setError(''); }} error={error} />
      <div className="flex flex-col gap-1">
        <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Icon</label>
        <div className="flex flex-wrap gap-2">
          {EMOJI_LIST.map(e => (
            <button key={e} onClick={() => setIcon(e)} className={`text-xl p-1.5 rounded-lg transition-colors ${icon === e ? 'bg-indigo-100 dark:bg-indigo-900/30 ring-2 ring-indigo-500' : 'hover:bg-gray-100 dark:hover:bg-gray-700'}`}>{e}</button>
          ))}
        </div>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Color</label>
        <div className="flex flex-wrap gap-2">
          {CATEGORY_COLORS.map(c => (
            <button key={c} onClick={() => setColor(c)} className={`w-7 h-7 rounded-full ${c} transition-transform ${color === c ? 'scale-125 ring-2 ring-offset-2 ring-gray-400' : 'hover:scale-110'}`} />
          ))}
        </div>
      </div>
      <Select label="Type" value={type} onChange={e => setType(e.target.value as any)}
        options={[{ value: 'expense', label: '💸 Expense' }, { value: 'income', label: '💵 Income' }, { value: 'both', label: '↔️ Both' }]}
      />
      <div className="flex gap-2">
        <Button variant="secondary" fullWidth onClick={onClose}>Cancel</Button>
        <Button variant="primary" fullWidth onClick={handleSave}>Add Category</Button>
      </div>
    </div>
  );
}

function SettingRow({ label, description, children }: { label: string; description?: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between py-3 px-4 border-b border-gray-50 dark:border-gray-700/50 last:border-0">
      <div className="flex-1 min-w-0 mr-4">
        <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
        {description && <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{description}</p>}
      </div>
      {children}
    </div>
  );
}

const SYNC_PROVIDERS: { id: SyncProvider; label: string; hint: string }[] = [
  { id: 'dropbox',     label: 'Dropbox',        hint: '~/Dropbox' },
  { id: 'onedrive',    label: 'OneDrive',       hint: '~/OneDrive' },
  { id: 'icloud',      label: 'iCloud Drive',   hint: '~/Library/Mobile Documents/com~apple~CloudDocs' },
  { id: 'googledrive', label: 'Google Drive',   hint: '~/Google Drive/My Drive' },
  { id: 'custom',      label: 'Custom folder',  hint: 'Any folder' },
];

export function SettingsPage() {
  const { settings, updateSettings, transactions, budgets, importData, clearAllData, deleteCategory, fileSyncActive, enableFileSync, disableFileSync } = useAppStore();
  const { darkMode, currency, categories, syncConfig } = settings;
  const [addCatOpen, setAddCatOpen] = useState(false);
  const [clearConfirm, setClearConfirm] = useState(false);
  const [syncProvider, setSyncProvider] = useState<SyncProvider>(syncConfig?.provider ?? 'dropbox');
  const [syncFolder, setSyncFolder] = useState(syncConfig?.folderPath ?? '');
  const [syncError, setSyncError] = useState('');
  const [syncBusy, setSyncBusy] = useState(false);
  const importRef = useRef<HTMLInputElement>(null);
  const isElectron = isElectronApp();

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const data = await importFromJSON(file);
      importData(data);
    } catch {
      alert('Failed to import: invalid file format');
    }
    e.target.value = '';
  };

  const handlePickFolder = async () => {
    const folder = await pickSyncFolder();
    if (folder) {
      setSyncFolder(folder);
      setSyncError('');
    }
  };

  const handleEnableSync = async () => {
    if (!syncFolder.trim()) { setSyncError('Please select a folder'); return; }
    setSyncBusy(true);
    setSyncError('');
    const result = await enableFileSync({
      enabled: true,
      provider: syncProvider,
      folderPath: syncFolder.trim(),
      filename: 'expense-tracker-data.json',
      lastSyncedAt: new Date().toISOString(),
    });
    setSyncBusy(false);
    if (!result.ok && 'error' in result) setSyncError(result.error ?? 'Failed to enable sync');
  };

  const handleDisableSync = async () => {
    await disableFileSync();
    setSyncFolder('');
    setSyncError('');
  };

  const customCategories = categories.filter(c => !['food','groceries','transport','housing','utilities','health','entertainment','shopping','education','travel','insurance','subscriptions','personal','gifts','other_exp','salary','freelance','investment','other_inc'].includes(c.id));

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Settings</h1>
        <p className="text-sm text-gray-500 dark:text-gray-400">Customize your experience</p>
      </div>

      {/* Appearance */}
      <Card>
        <div className="px-4 pt-4 pb-2">
          <h2 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Appearance</h2>
        </div>
        <SettingRow label="Dark mode" description="Switch between light and dark theme">
          <button
            onClick={() => updateSettings({ darkMode: !darkMode })}
            className={`relative w-12 h-6 rounded-full transition-colors flex-shrink-0 ${darkMode ? 'bg-indigo-500' : 'bg-gray-200 dark:bg-gray-600'}`}
          >
            <div className={`absolute top-1 left-1 w-4 h-4 bg-white rounded-full shadow transition-transform ${darkMode ? 'translate-x-6' : ''}`} />
          </button>
        </SettingRow>
        <SettingRow label="App icon">
          <div className="flex items-center gap-2">
            {darkMode ? <Moon size={16} className="text-indigo-400" /> : <Sun size={16} className="text-amber-400" />}
            <span className="text-sm text-gray-500 dark:text-gray-400">{darkMode ? 'Dark' : 'Light'}</span>
          </div>
        </SettingRow>
      </Card>

      {/* Currency */}
      <Card>
        <div className="px-4 pt-4 pb-2">
          <h2 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Currency</h2>
        </div>
        <div className="px-4 pb-4">
          <select
            className="w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            value={currency}
            onChange={e => updateSettings({ currency: e.target.value })}
          >
            {CURRENCIES.map(c => (
              <option key={c.code} value={c.code}>{c.symbol} {c.name} ({c.code})</option>
            ))}
          </select>
          <p className="text-xs text-gray-400 dark:text-gray-500 mt-2">
            This sets your default currency for new transactions.
          </p>
        </div>
      </Card>

      {/* Categories */}
      <Card>
        <div className="px-4 pt-4 pb-2 flex items-center justify-between">
          <h2 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Categories</h2>
          <button onClick={() => setAddCatOpen(true)} className="flex items-center gap-1 text-xs text-indigo-500 hover:text-indigo-600">
            <Plus size={12} />
            Add
          </button>
        </div>
        <div className="px-4 pb-3">
          <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">
            {categories.length} categories · {customCategories.length} custom
          </p>
          <div className="space-y-1 max-h-48 overflow-y-auto scrollbar-hide">
            {categories.map(cat => (
              <div key={cat.id} className="flex items-center gap-2 py-1">
                <div className={`w-6 h-6 rounded-full ${cat.color} flex items-center justify-center text-xs flex-shrink-0`}>
                  {cat.icon}
                </div>
                <span className="text-sm text-gray-700 dark:text-gray-300 flex-1">{cat.name}</span>
                <span className="text-xs text-gray-400 capitalize">{cat.type}</span>
                {customCategories.includes(cat) && (
                  <button onClick={() => deleteCategory(cat.id)} className="p-1 text-gray-400 hover:text-red-500">
                    <Trash2 size={12} />
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>
      </Card>

      {/* Export / Import */}
      <Card>
        <div className="px-4 pt-4 pb-2">
          <h2 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Data</h2>
        </div>
        <SettingRow label="Export as CSV" description={`${transactions.length} transactions`}>
          <Button variant="secondary" size="sm" onClick={() => exportToCSV(transactions, categories)}>
            <Download size={14} />
            CSV
          </Button>
        </SettingRow>
        <SettingRow label="Export as JSON" description="Full data backup">
          <Button variant="secondary" size="sm" onClick={() => exportToJSON({ transactions, budgets, settings })}>
            <Download size={14} />
            JSON
          </Button>
        </SettingRow>
        <SettingRow label="Import from JSON" description="Restore from backup">
          <Button variant="secondary" size="sm" onClick={() => importRef.current?.click()}>
            <Upload size={14} />
            Import
          </Button>
        </SettingRow>
        <input ref={importRef} type="file" accept=".json" className="hidden" onChange={handleImport} />
      </Card>

      {/* Cloud Sync (Electron only) */}
      {isElectron && (
        <Card>
          <div className="px-4 pt-4 pb-2">
            <h2 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Cloud Sync</h2>
          </div>
          {fileSyncActive ? (
            <div className="px-4 pb-4 space-y-3">
              <div className="flex items-center gap-2">
                <RefreshCw size={14} className="text-green-500 animate-spin" style={{ animationDuration: '3s' }} />
                <span className="text-sm font-medium text-green-600 dark:text-green-400">Sync active</span>
              </div>
              <p className="text-xs text-gray-500 dark:text-gray-400">
                Provider: {SYNC_PROVIDERS.find(p => p.id === syncConfig?.provider)?.label ?? syncConfig?.provider}
              </p>
              <p className="text-xs text-gray-400 dark:text-gray-500 truncate" title={syncConfig?.folderPath}>
                Folder: {syncConfig?.folderPath}
              </p>
              {syncConfig?.lastSyncedAt && (
                <p className="text-xs text-gray-400 dark:text-gray-500">
                  Last synced: {new Date(syncConfig.lastSyncedAt).toLocaleString()}
                </p>
              )}
              <Button variant="secondary" size="sm" onClick={handleDisableSync}>
                <CloudOff size={14} />
                Disable sync
              </Button>
            </div>
          ) : (
            <div className="px-4 pb-4 space-y-3">
              <p className="text-xs text-gray-500 dark:text-gray-400">
                Sync your data across devices by saving to a cloud-synced folder (Dropbox, OneDrive, iCloud Drive, or Google Drive).
              </p>
              <Select
                label="Cloud provider"
                value={syncProvider}
                onChange={e => { setSyncProvider(e.target.value as SyncProvider); setSyncError(''); }}
                options={SYNC_PROVIDERS.map(p => ({ value: p.id, label: p.label }))}
              />
              <div className="space-y-1">
                <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Sync folder</label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    className="flex-1 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    value={syncFolder}
                    onChange={e => { setSyncFolder(e.target.value); setSyncError(''); }}
                    placeholder={SYNC_PROVIDERS.find(p => p.id === syncProvider)?.hint ?? 'Path to folder'}
                  />
                  <Button variant="secondary" size="sm" onClick={handlePickFolder}>
                    <FolderOpen size={14} />
                  </Button>
                </div>
                {syncError && <p className="text-xs text-red-500">{syncError}</p>}
              </div>
              <Button variant="primary" size="sm" onClick={handleEnableSync} disabled={syncBusy}>
                {syncBusy ? 'Configuring...' : 'Enable sync'}
              </Button>
            </div>
          )}
        </Card>
      )}

      {/* iOS Install hint */}
      <Card className="p-4 bg-gradient-to-br from-indigo-50 to-purple-50 dark:from-indigo-900/20 dark:to-purple-900/20 border-indigo-100 dark:border-indigo-800">
        <p className="text-sm font-semibold text-indigo-900 dark:text-indigo-300 mb-1">📱 Add to iOS Home Screen</p>
        <p className="text-xs text-indigo-700 dark:text-indigo-400">
          In Safari, tap the Share button and choose "Add to Home Screen" to use this as a native-like app on your iPhone or iPad.
        </p>
      </Card>

      {/* Danger zone */}
      <Card>
        <div className="px-4 pt-4 pb-2">
          <h2 className="text-xs font-semibold text-red-500 uppercase tracking-wide">Danger Zone</h2>
        </div>
        <div className="px-4 pb-4">
          {!clearConfirm ? (
            <Button variant="danger" size="sm" onClick={() => setClearConfirm(true)}>
              <Trash2 size={14} />
              Clear all data
            </Button>
          ) : (
            <div className="space-y-2">
              <p className="text-sm text-red-600 dark:text-red-400 font-medium">This will delete ALL transactions, budgets and settings. Are you sure?</p>
              <div className="flex gap-2">
                <Button variant="secondary" size="sm" onClick={() => setClearConfirm(false)}>Cancel</Button>
                <Button variant="danger" size="sm" onClick={() => { clearAllData(); setClearConfirm(false); }}>
                  Yes, delete everything
                </Button>
              </div>
            </div>
          )}
        </div>
      </Card>

      <Modal open={addCatOpen} onClose={() => setAddCatOpen(false)} title="New Category">
        <AddCategoryForm onClose={() => setAddCatOpen(false)} />
      </Modal>
    </div>
  );
}
