import { withRouter } from 'react-router';
import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import CreatePostModal from './Modals/CreatePostModal';
import EditPostModal from './Modals/EditPostModal';
import DeletePostModal from './Modals/DeletePostModal';

import Helpers from './../Helpers';
import UserContext from './../Context/User';

class BlogPost extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showDeletePostModal: null,
            showEditPostModal: null,
            post: null
        };
    }

    componentDidMount() {
        this.load();
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevState.post !== this.state.post) {
            Helpers.scrollToHash();
        }
    }

    async load() {
        const response = await fetch(`/api/blog/${this.props.match.params.id}`);
        if (response.ok) {
            const result = await response.json();

            this.setState({
                post: result
            });
        }
    }

    async showDeletePostModal(post) {
        this.setState({
            showDeletePostModal: post
        });
        await this.load();
    }

    async showEditPostModal(post) {
        this.setState({
            showEditPostModal: post
        });
        this.load();
    }

    render() {
        const post = this.state.post;
        return (
            <UserContext.Consumer>{user => (
                <div className='showAutolinks'>
                    {post && <>
                        <h2 className='mb-0'>{post.title}</h2>
                        <div className='d-flex align-items-center mb-2 text-muted'>
                            <span><strong>Author:</strong> {post.owner.username}</span>
                            &nbsp;&nbsp;|
                            <span className='ps-2'><strong>Created:</strong> {new Intl.DateTimeFormat([], { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }).format(new Date(post.createdAt))}</span>
                            {post.isDraft && <span className='text-info ps-2'>(Draft)</span>}
                            {user && user.permissions.includes('blog') && <LinkContainer style={{cursor:'pointer'}} exact to={`/article/edit/${post.id}`}>
                                <span className='text-primary ps-2'>Edit <i class="bi bi-pencil-square"></i></span>
                            </LinkContainer>}
                        </div>
                        <hr className='mt-0' />
                        <div dangerouslySetInnerHTML={{__html: Helpers.parseMarkdown(this.state.post.content ? this.state.post.content : '(No Content)')}}></div>
                        <EditPostModal post={this.state.showEditPostModal} onSuccess={() => this.showEditPostModal(null)} onHide={() => this.showEditPostModal(null)} />
                        <DeletePostModal post={this.state.showDeletePostModal} didDelete={() => this.showDeletePostModal(null)} didCancel={() => this.showDeletePostModal(null)} onHide={() => this.showDeletePostModal(null)} />
                    </>}
                </div>
            )
        }</UserContext.Consumer>);
    }
}

export default withRouter(BlogPost);
