import type { JSX } from 'react';
import { CircleHelp, LogIn, Radio, RotateCcw } from 'lucide-react';

import { websiteText } from '../../app-state';
import { LegalPage } from './SiteFrame';

const issueIcons = [RotateCcw, LogIn, Radio, CircleHelp] as const;

export function SupportPage(): JSX.Element {
    const copy = websiteText.support;

    return (
        <LegalPage eyebrow={copy.eyebrow} intro={copy.intro} title={copy.title}>
            <section className='legal-section support-contact'>
                <h2>{copy.contactTitle}</h2>
                <p>{copy.contactBody}</p>
                <a
                    className='site-button site-button--primary'
                    href={`mailto:${websiteText.supportEmail}?subject=Atomize%20Support`}
                >
                    {copy.contactAction}
                </a>
                <p className='support-contact__note'>{copy.responseTime}</p>
            </section>
            <section className='legal-section'>
                <h2>{copy.commonTitle}</h2>
                <div className='support-grid'>
                    {copy.issues.map((issue, index) => {
                        const Icon = issueIcons[index];

                        return (
                            <article className='support-card' key={issue.title}>
                                <span className='support-card__icon'>
                                    <Icon aria-hidden='true' />
                                </span>
                                <div>
                                    <h3>{issue.title}</h3>
                                    <p>{issue.body}</p>
                                </div>
                            </article>
                        );
                    })}
                </div>
            </section>
        </LegalPage>
    );
}
