'use strict';
const D = require('./model');
const equal = (a, b) => JSON.stringify(a) === JSON.stringify(b);

class Expense {
  constructor(state) { this.state = structuredClone(state); }
  static record(input, catalog) {
    return new Expense({...D.normalizeExpense(input, catalog), source: 'manual',
      externalTxId: null, version: 1, isDeleted: false});
  }
  modify(changes, catalog) {
    if (this.state.isDeleted) D.fail('NotFound');
    const updated = D.normalizeExpense({...this.state,
      categoryId: D.resolved(catalog, this.state.categoryId), ...changes}, catalog);
    return equal(this.state, updated) ? this :
      new Expense({...updated, version: this.state.version + 1});
  }
  delete() { return new Expense({...this.state, isDeleted: true, version: this.state.version + 1}); }
}

class CategoryCatalog {
  constructor(state) { this.state = structuredClone(state); }
  upsert(input) {
    const c = this.state;
    if (input.categoryId === D.uncategorized || Object.hasOwn(c.retired, input.categoryId)) D.fail('InvariantViolation');
    if(typeof input.name!=='string'||!/^#[0-9a-fA-F]{6}$/.test(input.colorHex)) D.fail('ValidationFailed');
    const name = input.name.trim();
    if (!name || D.graphemes(name).length > 20 || !D.icons.includes(input.iconKey)) D.fail('ValidationFailed');
    if (c.categories.some(x => x.id !== input.categoryId && D.key(x.name) === D.key(name))) D.fail('InvariantViolation', 'name');
    const old = c.categories.find(x => x.id === input.categoryId);
    const next = {id: input.categoryId, name, nameKey: D.key(name), iconKey: input.iconKey,
      colorHex: input.colorHex, sortOrder: old?.sortOrder ?? c.categories.length, isSystem: false};
    if (old && equal(old, next)) return this;
    return new CategoryCatalog({...c, version: c.version + 1,
      categories: old ? c.categories.map(x => x.id === next.id ? next : x) : [...c.categories, next]});
  }
  reorder(ids) {
    const c = this.state;
    if (ids.length !== c.categories.length || new Set(ids).size !== c.categories.length ||
        ids.some(id => !c.categories.some(x => x.id === id))) D.fail('ValidationFailed');
    if (equal(ids, c.categories.map(x => x.id))) return this;
    return new CategoryCatalog({...c, version: c.version + 1,
      categories: ids.map((id, sortOrder) => ({...c.categories.find(x => x.id === id), sortOrder}))});
  }
  retire(id) {
    const c = this.state;
    if (id === D.uncategorized) D.fail('InvariantViolation');
    D.category(c, id);
    return new CategoryCatalog({...c, version: c.version + 1,
      retired: {...c.retired, [id]: D.uncategorized},
      categories: c.categories.filter(x => x.id !== id).map((x, sortOrder) => ({...x, sortOrder}))});
  }
}

class BudgetPlan {
  static configure(input, catalog, previous) {
    const {expectedVersion, ...plan} = input;
    if(!Number.isInteger(plan.monthlyAmount)||plan.monthlyAmount<1||plan.monthlyAmount>99999999||!Number.isInteger(plan.startDay)||plan.startDay<1||plan.startDay>28||typeof plan.notificationEnabled!=='boolean'||typeof plan.categoryBudgetEnabled!=='boolean') D.fail('ValidationFailed');
    for(const a of plan.allocations) if(!Number.isInteger(a.allocatedAmount)||a.allocatedAmount<0||a.allocatedAmount>99999999) D.fail('ValidationFailed','allocations');
    if (new Set(plan.allocations.map(a => a.categoryId)).size !== plan.allocations.length) D.fail('ValidationFailed', 'allocations');
    plan.allocations.forEach(a => D.category(catalog, a.categoryId));
    if (previous && equal({...previous, version: undefined}, {...plan, version: undefined})) return previous;
    return {...plan, version: expectedVersion + 1};
  }
  static removeAllocation(plan, categoryId) {
    return {...plan, allocations: plan.allocations.filter(x => x.categoryId !== categoryId), version: plan.version + 1};
  }
}
module.exports = {Expense, CategoryCatalog, BudgetPlan};
