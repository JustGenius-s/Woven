import { VocabularyEntry } from '../model/ContentModels';

export class VocabularyDataSource implements IDataSource {
  private items: VocabularyEntry[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): VocabularyEntry {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  reset(items: VocabularyEntry[]): void {
    this.items = items.slice();
    for (let index: number = 0; index < this.listeners.length; index++) {
      this.listeners[index].onDataReloaded();
    }
  }

  refresh(id: string): void {
    for (let index: number = 0; index < this.items.length; index++) {
      if (this.items[index].id !== id) {
        continue;
      }
      for (let listenerIndex: number = 0; listenerIndex < this.listeners.length; listenerIndex++) {
        this.listeners[listenerIndex].onDataReloaded();
      }
      return;
    }
  }
}
