export type DailySourceSection = {title: string; text: string; details: string; presentation?: string};
export function plainDailySections(sections: DailySourceSection[], options?: {key?: string; model?: string; request?: typeof fetch}): Promise<DailySourceSection[]>;
