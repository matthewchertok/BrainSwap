import type { PageServerLoad } from './$types';

export const load: PageServerLoad = ({ url }) => {
  const request = url.searchParams.get('request');
  return { request: request === 'sent' || request === 'failed' ? request : null };
};
